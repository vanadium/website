= yaml =
title: Verifying the Vanadium Authentication Protocol
layout: default
toc: true
= yaml =

This project defines a formalization of the [Vanadium authentication protocol][auth]
and verifies the desired security properties for it using the automatic cryptographic protocol verifier [ProVerif][proverif].

The authentication protocol is used during a [Vanadium RPC][rpc] for mutual
authentication and setting up an encrypted channel for sending RPC data.
More specifically, the protocol allows each end of an RPC to exchange [blessings]
with the other end and verify that the other end possesses the private key corresponding
to the public key to which its blessings are bound. At the end of the protocol,
an encrypted channel is established between the two ends for performing the
RPC. The blessings learned as part of the authentication may be used to
authorize the RPC (e.g., by checking that the blessing name is present on
a particular [access list][acl]).

The design of the protocol is very similar to the [SIGMA-I][sigma] protocol from
the literature. It involves a [Diffie-Hellman key exchange][ecdhe], followed by an
exchange of blessings and private key possession proofs. However, the protocol
differs from SIGMA-I in how this private key possession proof is represented. We
refer the reader to the [design doc][auth] for a detailed specification of the
protocol.

Decades of research in protocol design has shown that manually assessing the
security of a protocol is challenging as it is difficult to enumerate and
examine all possible attack scenarios. There have been a number of instances
of published protocols that intuitively seemed secure but had serious
vulnerabilities, e.g., the [Needham-Schroeder protocol][needham]. The only way to
guarantee security of a protocol is to formally specify it and mathematically
prove its security properties.

# ProVerif

[ProVerif][proverif] is a tool for automatically analyzing properties of security
protocols. It is capable of proving reachability properties, correspondence assertions,
and observational equivalence properties of protocols. The ProVerif specification language
is a variant of the [applied pi-calculus][applied-pi-calculus]. We refer the reader to the
[ProVerif manual][proverif-manual] for the authoritative definition of the language.

ProVerif analyzes protocols in the symbolic, [Dolev-Yao][dolev-yao] attacker model.
In this model, the attacker controls the communication channel between the protocol
participants and can read, modify, delete and inject messages. But the attacker
cannot "break" cryptographic primitives and can only use them via their legitimate
interfaces. For instance, the attacker can only decrypt those encrypted messages for
which it knows the encryption key.

ProVerif is sound but not complete. This means that if ProVerif confirms
that a security property is true then the property is indeed true in the Dolev-Yao attacker
model. However, not all true properties may be provable by ProVerif.

# Protocol Formalization

The complete formalization of the authentication protocol along with all cryptographic
primitives, and Vanadium primitives (such as: certificates and blessings) is specified
in [`protocol.pv`](/proofs/authentication/protocol.pv). The steps of the protocol are captured in the process
`handshake` that is parametric on the blessing and private key of the dialer and
the acceptor. Dialer (aka client) is the initiator of the first handshake message
and Acceptor (aka server) is the responder of the first handshake message.

# Security Properties

We verify three key properties of the authentication protocol.

(1) _Mutual Authentication_: The dialer and acceptor must agree on the
	established encryption key and each others blessings. This property
	is formalized as a pair of correspondence properties in ProVerif stating that a
	acceptor accepts a session if and only if the dialer accepts the same
	session, where a session is defined by the session encryption key and
	the public keys of the dialer's and acceptor's blessings.

(2) _Channel Confidentiality_: The session encryption key established
	is protected from attackers. This property is verified by checking
	that a message encrypted under the session key and sent from the
	acceptor to the dialer is not revealed to the attacker. This is specified
	as a reachability property in ProVerif.

(3) _Dialer Privacy_: The dialer's public key is never revealed to the attacker. This
	is specified as a reachability property in ProVerif. The acceptor's public key does get
	revealed to the attacker, and we verify this using another reachability
	property in ProVerif.

We verify security properties for an instantiation of the protocol process
(`authProtocol`) with randomly chosen private keys for the dialer and acceptor,
and randomly chosen blessings of depth two for the dialer and acceptor. We note
that the depth of the blessings in the instantiation should not affect the
security properties, i.e., the verification should go through for arbitrary
depth blessings if it goes through for depth two blessings. However, a formal
proof of this statement remains to be shown.

# Running the Verification

## Installing ProVerif
Running the verification requires installing the [ProVerif][proverif] tool.
Instructions for installing the tool can be found [here][proverif-install]

## Running ProVerif
Once ProVerif is installed, please set the environment variable
`PROVERIF` to point at the ProVerif binary.

```
export PROVERIF=<path to ProVerif binary>
```

The verification can be run using the following command.

```
$PROVERIF protocol.pv
```

## Intrepting the results
The aforesaid command prints out a bunch of ProVerif messages (we recommend
reading Section 3 of the [ProVerif manual][proverif-manual] to understand
these messages) with the verification results for the various properties
printed towards the end.

A simple way of printing just the verification results is to run the following
command:

```
$PROVERIF protocol.pv | grep RESULT
```

This command should print the following:

(We add line numbers for ease of reading.)

```
1. RESULT not attacker(publicKey(privKeyAcceptor[])) is false.

2. RESULT not attacker(publicKey(privKeyDialer[])) is true.

3. RESULT not attacker(privKeyAcceptor[]) is true.

4. RESULT not attacker(privKeyDialer[]) is true.

5. RESULT not attacker(secretMessage[]) is true.

6. RESULT event(termDialer(k,publicKey(privKeyDialer[]),publicKey(privKeyAcceptor[]))) ==> event(acceptsAcceptor(k,publicKey(privKeyDialer[]),publicKey(privKeyAcceptor[]))) is true.

7. RESULT event(acceptsAcceptor(k,publicKey(privKeyDialer[]),publicKey(privKeyAcceptor[]))) ==> event(acceptsDialer(k,publicKey(privKeyDialer[]),publicKey(privKeyAcceptor[]))) is true.
```

The first two messages respectively state that the attacker learns the
public key of the acceptor but not the dialer. This verifies the _dialer privacy_
property.

The next three messages respectively state that the attacker _does not_
learn the private key of the acceptor, the private key of the dialer, and
the secret message sent by the acceptor to the dialer over the established
encrypted channel. This verifies the _channel secrecy_ property.

The last two messages state two correspondence properties that
together imply that a dialer accepts a certain session if and
only if the acceptor also accepts the same session, where a session
is defined by the session encryption key and the public keys of
the dialer's and acceptor's blessings. This verifies the _mutual authentication_
property.

[auth]:/designdocs/authentication.html
[rpc]:/concepts/rpc.html
[acl]:/glossary.html#access-list
[blessings]:/glossary.html#blessings
[sigma]:http://webee.technion.ac.il/~hugo/sigma.html
[ecdhe]:https://en.wikipedia.org/wiki/Elliptic_curve_Diffie%E2%80%93Hellman
[proverif]:http://prosecco.gforge.inria.fr/personal/bblanche/proverif/
[proverif-manual]:http://prosecco.gforge.inria.fr/personal/bblanche/proverif/manual.pdf
[proverif-install]:http://prosecco.gforge.inria.fr/personal/bblanche/proverif/README
[applied-pi-calculus]:http://crysys.hu/members/tvthong/pispi/applied.pdf
[dolev-yao]:https://en.wikipedia.org/wiki/Dolev%E2%80%93Yao_model
[needham]:https://en.wikipedia.org/wiki/Needham%E2%80%93Schroeder_protocol
