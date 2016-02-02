= yaml =
title: Identity Service
toc: true
= yaml =

The [Vanadium Identity Service][`identityd`] generates [blessings][blessing].
It uses an [OAuth2] identity provider to get the email address of a user and
then issues a blessing with that email address. For example, after determining
that the user is `alice@university.edu` (using OAuth2), this service will issue
the blessing `dev.v.io:u:alice@university.edu` (where `dev.v.io` is
the namespace for which the public key of the identity service is considered
authoritative).  The blessing may also contain specific caveats per the user's
request.

Broadly, this identity service consists of two main components:

- **HTTPS Authentication Service**: This service authenticates the user using
  an OAuth2 Identity Provider, and securely hands out a token (henceforth
  called a macaroon) that encapsulates the user's authenticated identity and
  any caveats that the user may have requested to be added to the blessing. The
  cryptographic construction of macaroons ensures that their contents cannot be
  tampered with.
- **Vanadium Blessing Service**: This is a Vanadium RPC service with a method
  that exchanges the macaroon for a blessing. The principal invoking this RPC
  is blessed with a name and caveats extracted from the presented macaroon.

One additional service enables revocation of the blessings granted by the
blessing service:

- **Vanadium Discharge Service**: This is a Vanadium RPC service that enables
  revocation. The service issues [discharges][discharge] for a revocation
  [caveat] if the blessing has not been revoked by the user. The discharges are
  valid for 15 minutes.

All three services are exposed by a single binary - [`identityd`].  In order to
save users from talking to two different services (the HTTP service and the
Blessing service) and managing macaroons, we also provide a command-line tool -
[`principal`] - that talks to both of the services and obtains a blessing for
the principal that the tool is running as.

# Preliminaries

Before diving into the details of [`identityd`]'s design, some prerequisites:

- [Principals, Blessings and Caveats](../concepts/security.html).
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
`/google/seekblessings` | Receive blessing requests
`/google/caveats`       | Display a form for selecting caveats to be added to a blessing
`/google/sendmacaroon`  | Receive a POST request from the caveat selection form
`/google/listblessings` | Enumerate all blessings made by a particular user
`/google/revoke`        | Receive revocation requests

The blessing service is a Vanadium RPC service reachable via the name
`/ns.dev.v.io:8101/identity/dev.v.io/u/google` and presents the [`MacaroonBlesser`](https://github.com/vanadium/go.ref/blob/master/services/identity/identity.vdl) interface:
```
type MacaroonBlesser interface {
  // Bless uses the provided macaroon (which contains email and caveats)
  // to return a blessing for the client.
  Bless(macaroon string) (blessing security.WireBlessings | error)
}
```

# Blessing flow

The [`principal`] command-line tool is used to orchestrate the process of
obtaining a macaroon from the HTTPS Authentication Service and exchanging it
for a blessing from the Vanadium Blessing Service. The following sequence
diagram lists the network requests involved in this process:

![Blessing flow diagram](/images/blessing-flow.svg)

- Solid-line arrows represent HTTPS requests (except one HTTP to localhost).
- Dotted-line arrows represent Vanadium RPC requests.

Steps 1 thru 4 in the sequence diagram above result in the [`principal`] tool
invocation obtaining a macaroon.

Steps 5 and 6 exchange that macaroon for a blessing.

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
   - Generates a [blessing] with the name `dev.v.io:u:<email>` and the
     caveats extracted from the macaroon. This blessing is bound to the public
     key of the principal making the RPC request (i.e., `toolPublicKey`).
   - Records the creation of this blessing in a database which can be queried via
     `https://dev.v.io/auth/google/listblessings`.

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
[blessing]: ../glossary.html#blessing
[discharge]: ../glossary.html#discharge
[OAuth2]: http://oauth.net/2/
[caveat]: ../glossary.html#caveat
[HMAC]: http://en.wikipedia.org/wiki/Hash-based_message_authentication_code
[`principal`]: https://github.com/vanadium/go.ref/tree/master/cmd/principal
[web service flow]: https://developers.google.com/accounts/docs/OAuth2WebServer
[blessing root]: ../glossary.html#blessing-root
[authentication protocol]: authentication.html
[_Expiry_]: https://github.com/vanadium/go.v23/blob/master/security/caveat.vdl
[_Method_]: https://github.com/vanadium/go.v23/blob/master/security/caveat.vdl
[_PeerBlessings_]: https://github.com/vanadium/go.v23/blob/master/security/caveat.vdl
[_Revocation_]: https://github.com/vanadium/go.ref/tree/master/services/identity/internal/revocation
[discharge service]: https://github.com/vanadium/go.ref/blob/master/services/discharger/discharger.vdl
