= yaml =
title: Identity Service
toc: true
= yaml =

The [Vanadium Identity Service][`identityd`] generates [blessings][blessing].
It uses an [OAuth2] identity provider to get the email address of the user on
whose behalf the request is made and then issues a blessing for that email
address. Blessings issued by this service are of two kinds:

- **User-Blessing**: A user-blessing authorizes the (blessed) principal to act on
  behalf of the user. The blessing is  namespaced under the user's email address
  and is of the form `dev.v.io:u:<email>` (where `dev.v.io` is
  the namespace for which the public key of the identity service is considered
  authoritative on). For example, if `alice@university.edu` is the email
  address obtained for the user (using OAuth2) then the issued blessing has the name
  `dev.v.io:u:alice@university.edu`. These blessings are very powerful as they
  allow the principal to act on behalf of the user while making requests to any
  service. Thus the flow for obtaining these blessings involves selecting caveats
  that must be placed on the blessing in order to limit its scope.
- **Application-Blessing**: An app blessing authorizes the (blessed) principal to act on
  behalf of the user in the context of a specific application. The blessing is
  namespaced under the application identified in the request, and is of the form
  `dev.v.io:o:<appid>:<email>`. The
  application identifier and email address are obtained using OAuth2. Specifically,
  the applicaiton identifier is the `audience` field in the token's
  decription. For example, if  `alice@university.edu` is the email
  address obtained for the user and `xyz123` is an identifier for the requesting
  application then the issued blessing has the name `dev.v.io:o:xyz123:alice@university.edu`.
  An application-blessing is relatively less priveleged than a user-blessing as it
  does not allow the principal to arbitrarily act on behalf of the user.

Broadly, the identity service has three main components:

- **HTTPS Authentication Service**: Authenticates the user using
  an OAuth2 Identity Provider, and securely hands out a token (henceforth
  called a macaroon) that encapsulates the user's authenticated identity and
  any caveats that the user may have requested to be added to the blessing. The
  cryptographic construction of macaroons ensures that their contents cannot be
  tampered with.
- **Vanadium User-Blessing Service**: Exchanges the macaroon for a user-blessing
  via a Vanadium RPC. The blessing is bound to the principal invoking the RPC
  and has the name and caveats specified in the presented macaroon.
- **HTTPS Application-Blessing Service**: Exchanges an OAuth2 token
  and a public key for an application-blessing for the provided public key.
  The email address and application identifier specified in the blessing are
  determined using the provided OAuth2 token.

One additional service enables revocation of the granted blessings:

- **Vanadium Discharge Service**: Issues [discharges][discharge] for a revocation
  [caveat] if the blessing has not been revoked by the user. The discharges are
  valid for 15 minutes.

All services are exposed by a single binary - [`identityd`].  Since
user-blessings are quite powerful, it is important to limit their scope
using caveats. This complicates the flow for obtaining these blessings
and involves a sequence of interactions with the authentication service
and the Vanadium blessing service. In order to save users from interacting
with multiple services and exchanging credentials betweeen them, we also
provide a command-line tool - [`principal`] - that carries out the work of
communicating with the services and obtaining a user-blessing for the
principal that the tool is running as.

# Preliminaries

Before diving into the details of [`identityd`]'s design, some prerequisites:

- [Principals, Blessings and Caveats](/concepts/security.html).
- Third-party caveats: In a nutshell, a third-party caveat is a restriction on
  the use of a blessing that must be validated by a party other than the two
  communicating with and authorizing each other. The [blessing] with a
  third-party caveat is considered valid only if accompanied by a [discharge]
  issued by the third party that validated the restrictions. Discharges are
  unforgeable and cryptographically bound to the correpsonding third-party
  caveat.
- _Macaroons_: For the purposes of the identity service, a macaroon is a bearer
  token, similar to a cookie that can only be minted (and verified) by the
  identity service. A macaroon encapsulates state whose bits cannot be tampered
  with by anyone but the identity service. The state itself though is visible
  to the bearers of the macaroon. In particular, the identity service with a
  secret [HMAC] key `k` defines a macaroon for a state as:
  <code>Macaroon<sub>k</sub>(state) = HMAC(k, state)</code>
  The name "cookie" or "token" could have been used instead, but the term
  macaroon was an allusion to [this
  paper](http://research.google.com/pubs/archive/41892.pdf).

# Service interfaces

The HTTPS Authentication Service runs at https://dev.v.io/auth and uses the
Google OAuth2 [web service flow] for authenticating users.  It has a specific
OAuth2 ClientID and ClientSecret obtained from the Google Developer Console. It
supports the following routes:

Route                   |Purpose
------------------------|-----------------------------------
`/google/seekblessings` | Receive user-blessing requests
`/google/caveats`       | Display a form for selecting caveats to be added to a blessing
`/google/sendmacaroon`  | Receive a POST request from the caveat selection form
`/google/listblessings` | Enumerate all blessings made by a particular user
`/google/revoke`        | Receive revocation requests
`/google/bless`         | Receive application-blessing requests

The blessing service is a Vanadium RPC service reachable via the name
`/ns.dev.v.io:8101/identity/dev.v.io/u/google` and presents the [`MacaroonBlesser`](https://github.com/vanadium/go.ref/blob/master/services/identity/identity.vdl) interface:
```
type MacaroonBlesser interface {
  // Bless uses the provided macaroon (which contains email and caveats)
  // to return a blessing for the client.
  Bless(macaroon string) (blessing security.WireBlessings | error)
}
```

# User-Blessing flow

The [`principal`] command-line tool is used to orchestrate the process of
obtaining a macaroon from the HTTPS Authentication Service and exchanging it
for a user-blessing from the Vanadium Blessing Service. The following sequence
diagram lists the network requests involved in this process:

![Blessing flow diagram](/images/blessing-flow.svg)

- Solid-line arrows represent HTTPS requests (except one HTTP to localhost).
- Dotted-line arrows represent Vanadium RPC requests.

Steps 1 through  4 in the sequence diagram above result in the [`principal`] tool
invocation obtaining a macaroon.

Steps 5 and 6 exchange that macaroon for a user-blessing.

1. The tool generates a random state parameter `toolState` and starts an HTTP
   server on `localhost` for receiving the macaroon. `toolURI` denotes the URI
   of this server (e.g., `http://127.0.0.1:14141`), and `toolPublicKey` denotes
   the public key of the principal running the tool.
   It then directs the web browser on the machine to the HTTP Authentication
   Service while informing it of `toolURI`, `toolPublicKey` and the `toolState`
   parameters. For example, it might redirect to:
   `https://dev.v.io/auth/google/seekblessings?redirect_uri=<toolURI>&state=<toolState>&public_key=<toolPublicKey>`

2. The HTTP Authentication Service extracts `toolURI`, `toolState` and
   `toolPublicKey` and redirects the browser to the Google OAuth2 endpoint
   (using the [web service flow]). The `redirect_uri` provided to this endpoint
   is set to the page that presents a form to control caveats on the final
   blessing and the `state` parameter is set to: <code>oauthstate = Macaroon<sub>k</sub>(toolURI +
   toolState + toolPublicKey + serverCookie)</code> where `serverCookie` is a
   cookie set by the HTTP Authentication Service in the user's browser. This leads
   the user's browser to a URL like:
   `https://accounts.google.com/o/oauth2/auth?client_id=...&redirect_uri=https://dev.v.io/auth/google/caveat&state=oauthstate`

   The Google OAuth2 endpoint asks the user to login and grant access to email
   address to the Vanadium Identity Server, after which it redirect the browser
   back to:
   `https://dev.v.io/auth/google/caveats?code=<authcode>&state=<oauthstate>`

3.  The caveats page at the HTTP Authentication Service receives `authcode` and
    `oauthstate`. It then:
    - Verifies that `oauthstate` is a valid macaroon generated by step 2.
    - Extracts `toolURI`, `toolState`, `toolPublicKey` and `serverCookie` from the macaroon.
    - Verifies that `serverCookie` matches the cookie presented by the browser
    - Exchanges `authcode` for an email address (via an identity token) using
      the OAuth2 client-secret.
    - Displays a form for selecting caveats to be added to the blessing that
      will ultimately be provided to the [`principal`] tool started in step 1.
      Embedded in this form is `formstate = Macaroon<sub>k</sub>(toolURI + toolState + toolPublicKey + email + serverCookie)`.

4. When the user submits the form rendered in step 3, the browser sends the form
   contents to `https://dev.v.io/auth/google/sendmacaroon` which performs the
   following steps:
   - Verifies that `formstate` is a valid macaroon.
   - Extracts `toolURI`, `toolState`, `toolPublicKey`, `email` and `serverCookie` encapsulated
     in the macaroon.
   - Verifies that `serverCookie` matches the cookie presented by the browser.
   - Verifies that `toolURI` is a localhost URI.
   - Computes <code>M = Macaroon<sub>k</sub>(email, toolPublicKey, caveats)</code>.
   - Redirects the browser to:
     `https://<toolURI>/macaroon?state=<toolState>&macaroon=M&root_key=publicKey`
     where `publicKey` is the [blessing root] of the identity service.

5. The `principal` tool receives the macaroon `M`, `toolState` and the
   [blessing root] via the HTTP redirect in step 4. It then:
   - Verifies that `toolState` obtained here matches the one created in step 1.
   - Invokes the `Bless` RPC on the blessing service passing it `M` as an argument.
     It only sends this request if the the RPC server proves that it's public key
     is `publicKey` via the [authentication protocol] used in RPCs.

6. The Vanadium Blessing Service that receives this RPC performs the following steps:
   - Verifies that the macaroon presented is valid.
   - Extracts `email`, `toolPublicKey` and `caveats` from it.
   - Verifies that the principal making the RPC request has the same public key
     as `toolPublicKey`. This check ensures that the macaroon can only be used by
     the principal tool that requested it in the first place. It protects against
     impersonation attacks wherein an attacker steals the macaroon handed out in
     step 5 and then tries to obtain a blessing for the email address encapsulated
     in the macaroon.
   - Generates a user-blessing with the name `dev.v.io:u:<email>` and the
     caveats extracted from the macaroon. This blessing is bound to the public
     key of the principal making the RPC request (i.e., `toolPublicKey`).
   - Records the creation of this blessing in a database which can be queried via
     `https://dev.v.io/auth/google/listblessings`.


# Application-Blessing flow

Any application that possesses an OAuth2 token can make
a request for an application-blessing. Such a request is made via GET request to
the HTTPS Application-Blessing Service. The request must include the following
parameters:
- `public_key`: Base64URL DER encoded PKIX representation of the public key to
  be blessed.
- `token`: Google OAuth2 access token
- `caveats`: Base64URL VOM encoded list of caveats. This parameter is optional.
- `output_format`: The encoding format for the returned blessings. The following
  formats are supported:
  - `base64vom`: Base64URL encoding of VOM-encoded blessings [Default]
  - `json`: JSON-encoded blessings.

For example, the request URL may be:
`https://dev.v.io/auth/google/bless?public_key=<publicKey>&token=<token>`

The token provided must be a Google OAuth2 access token but may be bound to any
OAuth2 Client ID. The Vanadium identity service may not have a pre-existing
relationship with the application that the ClientID has been registered for.

When the service receives a request for an application-blessing, its presents the
provided token to Google's [`tokeninfo`][tokeninfo] endpoint, and among other things,
obtains the email address and the ClientID that the token is bound to. (In particular,
the ClientID is obtained from the `aud` field of the [`tokeninfo`][tokeninfo] struct.)
The service then generates an application-blessing for the provided public key. By
default, the application identifier is set to the ClientID obtained from the access
token. In some cases, the application corresponding to the ClientID may have
[registered](https://vanadium-review.googlesource.com/#/c/19913/)
a specific name with the Vanadium identity service, in which case, that name is used
as the application identifier. The generated blessing carries any caveats provided
during the request.

# Supported caveats

The caveat addition form presented to the user in step 4 supports a few types
of caveats:

- [_Expiry_]: Which limits the time period during which the blessing is valid.
- [_PeerBlessings_]: Which limits the set of peers that the blessing will be recognized by.
- [_Method_]: Which limits the set of methods that can be invoked with the blessing.
- [_Revocation_]: Which allows the user to revoke the blessing at any time in
  the future by visiting https://dev.v.io/auth/google/listblessings.

## Revocation

The revocation caveat that is (at the user's request) added to the blessing is
a third-party caveat with a unique 16-byte ID and the object name of the
discharging service. Each time a revocation caveat is created, the blessing
service stores the corresponding ID and the revocation status in a SQL
database.

The [discharge service] run by [`identityd`] extracts the ID from the caveat
and looks it up in the database. If the database suggests that blessing should
be revoked, it refuses to issue a discharge.

This is implemented in
[services/identity/internal/revocation](https://github.com/vanadium/go.ref/tree/master/services/identity/internal/revocation).

Revocation can be triggered by clicking buttons on https://dev.v.io/auth/google/listblessings.


[`identityd`]: https://github.com/vanadium/go.ref/tree/master/services/identity/identityd
[blessing]: /glossary.html#blessing
[discharge]: /glossary.html#discharge
[OAuth2]: http://oauth.net/2/
[caveat]: /glossary.html#caveat
[HMAC]: http://en.wikipedia.org/wiki/Hash-based_message_authentication_code
[`principal`]: https://github.com/vanadium/go.ref/tree/master/cmd/principal
[web service flow]: https://developers.google.com/accounts/docs/OAuth2WebServer
[blessing root]: /glossary.html#blessing-root
[authentication protocol]: /designdocs/authentication.html
[_Expiry_]: https://github.com/vanadium/go.v23/blob/master/security/caveat.vdl
[_Method_]: https://github.com/vanadium/go.v23/blob/master/security/caveat.vdl
[_PeerBlessings_]: https://github.com/vanadium/go.v23/blob/master/security/caveat.vdl
[_Revocation_]: https://github.com/vanadium/go.ref/tree/master/services/identity/internal/revocation
[discharge service]: https://github.com/vanadium/go.ref/blob/master/services/discharger/discharger.vdl
[tokeninfo]:https://developers.google.com/identity/protocols/OAuth2UserAgent#validatetoken
