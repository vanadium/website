= yaml =
title: Authentication Protocol
toc: true
= yaml =

When a network connection is established between two Vanadium processes, they
authenticate each other, i.e., exchange blessings so that both ends can
identify the specific principal at the other end. The remote blessing names are
then used to authorize RPCs.  This document describes:
- the properties desired from the authentication protocol
- the current implementation that provides these properties
- the reasons behind various design choices in a question-and-answer format.

# Principals & blessings

A [principal] is defined by a unique (public, private) key pair `(P, S)` and a
set of blessings in the form of certificate chains that bind a name to `P`.
For more details, read [security concepts].

Within the Go codebase, the set of blessings is encapsulated within the
[`v.io/v23/security.Blessings`] type. The principal and all private key
operations are encapsulated in the [`v.io/v23/security.Principal`] type.

# Authentication

Communication between two processes takes place after they establish a
confidential, authenticated connection. Encryption with keys derived from an
[Elliptic curve Diffie-Hellman] (ECDH) exchange is used to provide message
confidentiality and integrity . The goal of the authentication protocol is to
exchange the blessings in a way that provides the following properties:

1. _Session binding_: The private counterpart `S` of the public key `P` to
   which the blessings are bound must be possessed by the same process with
   which the session encryption keys have been established.
2. _Client Confidentiality_: An eavesdropper listening in on all communication between
   the two processes cannot determine the set of blessings presented by the initiator of
   the connection (the "Client").

# Current implementation

As of April 2015, the reference implementation of the Vanadium networking stack
in [`v.io/x/ref/runtime/internal/rpc/stream`] provides confidential,
authentication communication streams (referred to as virtual circuits or VCs).
Blessings bound to the public key used to establish the communication stream
are provided with each RPC request.

In this implementation, [NaCl/box] is used to establish an
[authenticated-encryption] channel based on an ECDH key exchange.

![Authentication flow diagram](/images/authentication-flow.svg)

Where:
- `{foo}k` represents the message `foo` encrypted using the key `k`
- Channel bindings C1 and C2 at the Client and Server ends respectively are
  constructed by appending a specific tag to the (sorted) pair of [NaCl/box]
  public keys generated for the session. The tags are different for the Client
  and Server ends, and are meant to prevent [type
  flaws](http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.106.6010&rep=rep1&type=pdf).
  The public key is a 32-byte string distinct from the public key `P` to which
  the blessings are bound.
- If the Client is not happy with the blessing names presented by the Server,
  it can abort the connection without ever revealing its blessings.

## Correctness Proof

The protocol along with the guarantees that it makes has been formalized in
[ProVerif] to provide a proof of correctness. This formalization is available
at https://vanadium.github.io/proofs/authentication

## Code pointers

Pointers to code in the reference implementation of the Vanadium APIs:
- Session encryption is encapsulated in the [`Crypter`](https://github.com/vanadium/go.ref/blob/master/profiles/internal/rpc/stream/crypto/crypto.go) interface
- [NaCl/box implementation of the
  interface](https://github.com/vanadium/go.ref/blob/master/profiles/internal/rpc/stream/crypto/box.go)
- The authentication protocol is implemented by the `AuthenticateAsClient` and
  `AuthenticateAsServer` functions in
  [`v.io/x/ref/runtime/internal/rpc/stream/vc/auth.go`](https://github.com/vanadium/go.ref/blob/master/profiles/internal/rpc/stream/vc/auth.go).

# Questions

- *Why don't the the Client and Server send their blessings in parallel,
  instead of Server first?*

  Doing so provides Client privacy.

  If the Client sent its blessings before validating that it trusts the Server,
  then an active network intermediary can learn the Client's blessings
  and compromise Client privacy as it will learn of the Client's intention to
  communicate.

- *Can an intermediary fake a blessing by modifying messages between the Client
  and Server?*

  No.

  Since all messages are exchanged using a negotiated encryption key, the only
  malicious intermediary to consider is one that breaks the connection and
  establishes separate encrypted sessions with the Client and Server. Doing so
  will result in different channel bindings and the processes will realize that
  they are not directly connected.

  This session binding technique is inspired by Dirk Balfanz and Ryan Hamilton's
  [channel ids] proposal.

- *Did you consider using TLS instead of NaCl/box?*

  Initially, TLS was used instead of NaCl/box to establish the encrypted
  sesssion. However, only a stripped down version was needed (since TLS
  was used only for establishing an encrypted session, not for authentication
  via exchange of blessings) and the libraries being used made this more
  heavy-weight than NaCl/box. For example, using TLS required 3 round-trips
  to establish the session keys while with NaCl/box, a single round-trip
  suffices.

- *Why are blessings encrypted with the session key?*

  The reason is threefold:

  - To bind the session key to the blessings presented by each end. By encrypting its
  blessings under the session key (using an [authenticated-encryption] scheme) each end
  proves knowledge of the session key to the other end.
  - To prevent passive network sniffers from determining the blessings being
  exchanged over a network connection.
  - To prevent active network attackers from learning the Client's blessings.

[authenticated-encryption]: http://en.wikipedia.org/wiki/Authenticated_encryption
[security concepts]: /concepts/security.html
[Elliptic curve Diffie-Hellman]: http://en.wikipedia.org/wiki/Elliptic_curve_Diffie%E2%80%93Hellman
[session resumption is not used]: https://secure-resumption.com/#channelbindings
[channel ids]: http://tools.ietf.org/html/draft-balfanz-tls-channelid-00
[principal]: /glossary.html#principal
[`v.io/v23/security.Blessings`]: https://godoc.org/v.io/v23/security#Blessings
[`v.io/v23/security.Principal`]: https://godoc.org/v.io/v23/security#Principal
[`v.io/x/ref/runtime/internal/rpc/stream`]: https://godoc.org/v.io/x/ref/runtime/internal/rpc/stream
[NaCl/box]: https://godoc.org/golang.org/x/crypto/nacl/box
[ProVerif]:http://prosecco.gforge.inria.fr/personal/bblanche/proverif/
