= yaml =
title: Security
sort: 3
toc: true
= yaml =

The Vanadium security model defines mechanisms for identification,
authentication, and authorization.  The model supports fully decentralized,
fine-grained, and auditable delegation of authority.

For example, Alice could choose to delegate access to Bob only
under the following conditions:
* the operation is <code>Read</code>, and
* the current time is between <code>6PM and 8PM</code>, and
* Bob is in Alice's <code>"friends"</code> group, and
* Bob is in close physical proximity of Alice

Such delegations do not have to go through the cloud or any centralized
service, can be accomplished by a single interaction between Alice and Bob,
and encode an audit trail of the principals involved in the delegation.

All network communication is always mutually authenticated and
encrypted.  The model is heavily influenced by the work on [Simple
Distributed Security Infrastructure] by Ronald Rivest and Butler Lampson.

# Principals & blessings

The security model is centered around the concepts of _principals_ and
_blessings_. A _principal_ in the Vanadium framework is a public and
private [key pair].  All Vanadium processes act on behalf of a principal.
The notation (<code>P<sub>Alice</sub>, S<sub>Alice</sub></code>) is used
to refer to the public and private key respectively of a principal Alice.

Principals have a set of human-readable names bound to them, via _blessings_.
For instance, a television principal, represented by the key pair
(<code>P<sub>tv</sub>, S<sub>tv</sub></code>), may have a blessing from the
manufacturer with the human-readable name of `popularcorp:products:tv`.
Principals can have multiple blessings bound to them and thus have multiple
names, each reflecting the principal that granted the blessing. For example,
the particular PopularCorp tv owned by Alice might also have the name
`alice:devices:hometv`.

Principals are authenticated and authorized based on the blessing names bound to them.
For example, a service may grant access to `alice:devices:hometv`, which means that all
principals with a blessing name matching `alice:devices:hometv` will have access.
Service administrators always use blessing names, not public keys, when making
authorization decisions or inspecting audit trails.

Concretely, blessings are represented by [public-key certificate] chains bound to the
principal's public key.  For example, the name
`popularcorp:products:tv` could be bound to the public key
<code>P<sub>tv</sub></code> using a chain of three certificates:

1. Certificate with public key <code>P<sub>popularcorp</sub></code> and name
`popularcorp`, _chained to_
2. Certificate with public key <code>P<sub>products</sub></code> and name `products`, _chained to_
3. Certificate with public key <code>P<sub>tv</sub></code> and name `tv`

Chaining means that the certificate is signed by the private counterpart of the
public key in the previous certificate. The first certificate in the chain
is self-signed, i.e. signed by private counterpart of the public key mentioned
in the certificate (<code>P<sub>popularcorp</sub></code> in this case).

The first certificate is also called the _root certificate_ and the first
certificate's public key is called the _blessing root_.

The term _blessing_ is used to refer to a certificate chain and the term
_blessing name_ is used to refer to the human-readable name specified in the
certificate chain.  If it is clear from the context, then _blessing_ may be
used in lieu of _blessing name_ for brevity.

The private key of the principal will generally be hosted by a [TPM] (Trusted
Platform Module) or an agent process and will not be held in memory of the
application process to protect against leakage. Private keys are never sent on
the network and are used only for digital signing operations.

# Mutual authentication

Clients and servers in a Vanadium remote procedure call (RPC) always act on
behalf of a principal, and mutually authenticate each other via blessings bound
to the other end's principal.  The [Vanadium authentication protocol] allows
clients and servers to exchange blessings bound to them, and verify that the
other end possesses the private counterpart of the public key to which their
blessings are bound.  At the end of the protocol, an encrypted channel is
established between the client and server for performing the RPC.
[Forward-secrecy] safe protocols (like [TLS] with [ECDHE] key exchanges or a
[NaCl box] with ephemerel keys) are used for setting up the encrypted channel.

# Delegation

The authorizations associated with a principal are determined solely by the
blessings bound to the principal.  Delegation of authority across principals is
achieved via the _Bless_ operation.  Bless allows a principal to extend one
of its blessings and create a blessing bound to another principal's public key,
thereby delegating any authorizations associated with the blessing.

For example, a principal (<code>P<sub>alice</sub>, S<sub>alice</sub></code>) may bless another principal
(<code>P<sub>tv</sub>, S<sub>tv</sub></code>) by extending one of
her blessings, say `alice`, with a certificate with the name `devices:hometv` and the tv's public key
<code>P<sub>tv</sub></code>. This certificate is signed with the secret key of the blesser
(<code>S<sub>alice</sub></code>). The blessing can therefore be viewed as making
the statement

> <code>P<sub>alice</sub></code> using name <code>alice</code> says that
> <code>P<sub>tv</sub></code> can use the name
> <code>alice:devices:hometv</code>

Blessing names are thus hierarchical, with colons used to distinguish the
blesser (`alice`) from the blessee (`devices:hometv`).

# Caveats

In practice, delegation of authority is never unconditional and this is
supported by the security model. Blessings can carry caveats that restrict the
conditions under which the blessing can be used.  For example, a principal
(<code>P<sub>alice</sub>, S<sub>alice</sub></code>) can bless
another principal (<code>P<sub>bob</sub>, S<sub>bob</sub></code>)
as `alice:houseguest:bob` but with the caveat that the blessing can only be used
to talk to her TV (and not to remote services that Alice uses).
This caveat is specified in the certificate written by `alice` (for Bob's public key
<code>P<sub>bob</sub></code>).  Thus the blessing makes a signed statement of
the form:

> <code>P<sub>alice</sub></code> using name <code>alice</code> says that
> <code>P<sub>bob</sub></code> can use the name
> <code>alice:houseguest:bob</code> _as long as_<br>
  * <code>server</code> matches `alice:devices:hometv`

When Bob presents this blessing to a server, the server will recognize the
principal as `alice:houseguest:bob` only if the server's own blessing name
matches `alice:devices:hometv`.

Caveats can be placed on any information available at the time of the request.
This includes, among other things, the time the request is being made, whether
the blessing wielder is a client or a server, the communication protocol being
used and the method being invoked.

## Third-party caveats

Validation of some caveats may involve expensive computation or I/O or
information not accessible to the authorizing service. In such cases, the
blesser can push the burden of validation to a _third party_ (i.e., neither the
 party that wields the blessings nor the party that is authorizing them). For
example, Alice can allow Bob to use the blessing `alice:houseguest:bob` only if
bob is within 100 feet of Alice's home. When bob wants to authenticate as
`alice:houseguest:bob`, he must obtain a _discharge_ (proof) from the third-party
service `home_proximity_discharger` (mentioned in the caveat) before he can
use the name `alice:houseguest:bob`. Thus the blessing makes the signed
statement:

> <code>P<sub>alice</sub></code> using name <code>alice</code> says that
> <code>P<sub>bob</sub></code> can use the name
> <code>alice:houseguest:bob</code> _as long as_<br>
   * <code>home_proximity_discharger</code> issues a discharge after validating that
   <code>P<sub>bob</sub></code> is <code>"within 100 ft"</code> of it.

By using such _third-party caveats_, the burden of making the network calls to
obtain a discharge and the burden of any computation or I/O to validate the
restrictions are moved to the wielder of the blessing and to the third-party respectively, away from the end at which the authorization decision is being made.

# Validating blessings

A blessing is considered valid in the context of an RPC if and only if
- the blessing is cryptographically valid, i.e., each certificate in the
  blessing's certificate chain has a valid signature.
- all caveats associated with the blessing are valid in the context of the RPC
- the blessing is recognized.

A blessing is _recognized_ by a Vanadium application if and only if the
application considers the blessing root as authoritative for the blessing name.
(Recall that blessing root is the public key of the first certificate in the
blessing's certificate chain.)

For example, an application may consider the root
<code>P<sub>popularcorp</sub></code> as authoritative on all blessing names
that begin with `popularcorp`. Such an application would then recognize the
blessing `popularcorp:products:tv` if it is rooted in
<code>P<sub>popularcorp</sub></code>.

All Vanadium applications are configured to consider certain blessing roots as
authoritative for certain names, and this configuration may vary across
applications.

# Authorization

In a remote procedure call, two authorization decisions need to be made:


- Does the client trust the server enough to __make__ a call? Making a call
  reveals the identity of the client (i.e., its blessings), the object being
  manipulated, the method being invoked and the arguments.
- Does the server allow the client to invoke a _method_ on an _object_ with
  the provided _arguments_?

Both these decision are made using the following principle:
<center><h4>Authorization is based on validated blessing names</h4></center>

For example, a client may wish to invoke the `Display` method on a service only
if the server presents a blessing matching the pattern `alice:devices:hometv`.
Similarly, the service may allow a client to invoke the `Display` method only
if the client presents a blessing matching the pattern `alice:houseguest`.

The public keys of the client and server principals do not matter as long as
they present a blessing with a valid name matching the other end's
authorization policy.  Each end ascertains the valid blessing name of the other
end by validating all caveats associated with the blessing and verifying that the
blessing is recognized.

A pattern is a blessing name that may optionally end in a `:$`. If the pattern
ends in a `:$``, it is only matched by the exact blessing name. Otherwise, it
is matched by the blessing name and all its extensions.

For example, the pattern `alice:houseguest` will be matched by the name `alice:houseguest`
and its extensions (e.g., `alice:houseguest:bob`) but
not by the name `bob` or `alice:colleague` or prefixes of the pattern (i.e.
`alice`).  On the other hand, the pattern `alice:houseguest:$` would be matched
exactly by the name `alice:houseguest`.

## Selecting a blessing

A principal may have collected multiple blessings and may need to choose which
subset of them to present when authenticating with a peer. It could present
all, at the cost of leaking sensitive information (e.g., `bob` is a houseguest
of `alice`) when not necessary. Instead Vanadium provides a means to
selectively share blessings with appropriate peers.

All blessings for a principal are stored in a _blessing store_, akin to a
cookie jar in web browsers. The store marks the blessings to be presented when
acting as a server (and a server always reveals its blessings first as per the
[Vanadium authentication protocol]). Clients select a subset of their blessings
from the store to share with a server based on the blessing names of the
server.

For example, Bob's blessing store can add the blessing `alice:houseguest:bob`
to the store only to be shared with servers matching the pattern `alice`.
Thus, all servers run by alice (such as `alice:hometv` and `alice:homedoor`)
will see the `alice:houseguest:bob` blessing when Bob makes requests to them,
but any other servers that Bob communicates with will not know that he has this
blessing from Alice.

# FAQs

- **What is the plan for storing keys and blessings?**

  All "credentials" of a principal (its private key, blessings, recognized blessing
  roots) are stored in a `V23_CREDENTIALS` directory on the file
  system. In the short term, the private key is kept encrypted at rest and
  decoded in memory by an 'agent' process. The 'agent' process is the only one
  with access to the private key and can audit usage of the key, similar to how
  'ssh-agent' works. Longer term, we envision wider use of [TPM]s and the key
  being kept securely in them.

- **Why is authorization based on blessing patterns as opposed to fixed
  blessing names?**

  The main motivations for using patterns (as opposed to fixed strings) for
  authorization are to encourage delegation, enable auditing, and discourage
  insecure workarounds.  For example, if Alice's tv authorizes based on the
  pattern `alice:houseguest`, then an authorized principal Bob with the
  blessing `alice:houseguest:bob` can delegate Carol to use the tv by blessing
  her with the name `alice:houseguest:bob:friend` (with appropriate caveats).
  This name would match the blessing pattern `alice:houseguest`.  By making
  safely constrained delegation easy, Vanadium aims to discourage insecure
  workarounds. If delegates were not authorized and Bob really wanted to share
  access to Alice's tv with Carol, he may be tempted to work around the
  restriction by running a proxy service for Carol. Alternatively, he could
  create a new private key, get that blessed as `alice:houseguest:bob` and
  share the key with Carol.  By making blessings and patterns easy to use
  instead, Bob is discouraged from trying out these hacks.

  Having said that, patterns can also terminate with a `$` which forbid
  delegation.  So the pattern `alice:$` will only be matched by the blessing
  name `alice` and not by `alice:houseguest` etc. While this facility does
  exist, application developers and administrators are encouraged to think hard
  about why they want to disallow delegation and whether doing so will
  encourage hacky, insecure workarounds.

- **Why does the pattern `alice:houseguest` not match prefixes like `alice`?**

  The pattern `alice:houseguest` matches the blessing name `alice:houseguest`
  and any delegates like `alice:houseguest:bob` or `alice:houseguest:carol`,
  but not `alice` itself. Doing so does not really prevent `alice` from
  accessing the resource, as `alice` can generate the blessing name
  `alice:houseguest:foo` for herself at any time. However, this does protect
  against accidental use of authority.

  Think of how `sudo` works in UNIX-based systems. Users with `sudo` access can
  act as the superuser, but they must explicitly do so by invoking the `sudo`
  command. Similar to that, `alice` can generate the blessings required to
  access resources protected by the pattern `alice:houseguest`, but she must
  explicitly choose to do so by blessing herself.

- **The authorization story described above demonstrates that there are two
  ways to authorize a client to invoke methods at a server: (1) add the
  blessing names of the client to the access list, or (2) bless the client,
  providing it with a blessing name (with caveats) that matches an existing
  entry in the access list.  Which method is appropriate?**

    The appropriate method of authorization would depend on who wants to
    authorize whom and why. For example, consider these simple questions:

    - _Do you have the ability to change the access list?_

      It is likely that only `alice` can change the access list on the tv
      (since she owns it). Thus, if `alice:houseguest:bob` wants to provide
      `carol` with access to the tv, his options are to either bless `carol` or
      find `alice` and trouble her to change the access list or try workarounds
      like proxying the RPC.

      On the other hand, if `alice` knows that `dave` should be able to access
      the tv then she can add `dave` to the access list and avoid the need to
      communicate with `dave` (to bless him) first.

    - _Are there conditions on the access?_

      Blessings allow for caveats on their use. For example,
      `alice:houseguest:bob` can only be used within 100ft of the house. For
      simplicity, Vanadium currently intends to support such caveats only on
      blessings and keep access lists as simple lists of patterns (instead of
      being able to specify arbitrary caveats in the access list).

- **What are the privacy implications of exchanging blessings using the
  [Vanadium authentication protocol]? **

  Blessings can often contain [personally identifiable information] such as
  usernames and email addresses, and therefore revealing them to unauthorized
  parties poses a privacy risk. (Note that revealing blessings to unauthorized parties
  does not pose a security or authorization risk as the blessings can
  only be used by the principal they are bound to.)

  The [Vanadium authentication protocol] ensures that blessings are always exchanged
  over an encrypted channel and thus are protected from passive eavesdroppers.
  Protecting blessings from active attackers -- ones that can pose as a
  legitimate peer to the client or the server -- is more challenging. The protocol protects
  the client's blessings from being revealed to unauthorized recipients at the cost of
  revealing the server's blessings to all clients.

  Servers always reveal their blessings first. This means that any client can learn the
  server's blessings by making a request to the server. The server can choose what
  blessings it authenticates with, and it is advisable that the server only choose blessings
  that it is comfortable revealing to all clients.

  Clients reveal their blessings only after seeing the server's blessings.
  Clients can control the blessings revealed to individual servers by tagging blessings with
  _server patterns_ in their [blessing stores](#selecting-a-blessing).
  A server pattern is a blessing pattern indicating that the specific blessing it accompanies can
  only be revealed to servers that have a blessing name matching the pattern.

  For example, if a client has a blessing `alice:houseguest` tagged with the pattern
  `alice:devices` in its blessing store then the blessing will only be revealed to servers that have
  blessings matching the pattern `alice:devices` (e.g.,`alice:devices:tv`).
  Other services (e.g., `carol:homedoor`) that the client communicates with will never see
  this blessing and thus never learn that the client is Alice's _houseguest_.

[TLS]: http://en.wikipedia.org/wiki/Transport_Layer_Security
[ECDHE]: http://en.wikipedia.org/wiki/Elliptic_curve_Diffie%E2%80%93Hellman
[Public-key cryptography]: http://en.wikipedia.org/wiki/Public-key_cryptography
[key pair]: http://en.wikipedia.org/wiki/Public-key_cryptography
[Public-key certificate]: http://en.wikipedia.org/wiki/Public_key_certificate
[Forward-secrecy]: http://en.wikipedia.org/wiki/Forward_secrecy
[NaCl box]: http://nacl.cr.yp.to/box.html
[Vanadium authentication protocol]: /designdocs/authentication.html
[TPM]: http://en.wikipedia.org/wiki/Trusted_Platform_Module
[Simple Distributed Security Infrastructure]: http://people.csail.mit.edu/rivest/sdsi11.html#secoverview
[personally identifiable information]: http://en.wikipedia.org/wiki/Personally_identifiable_information
