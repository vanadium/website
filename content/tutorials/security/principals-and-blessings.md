= yaml =
title: Principals and Blessings
layout: tutorial
wherein: Alice and her friend Bob take the stage to demonstrate inter-principal communication.
prerequisites: {scenario: b}
sort: 21
toc: true
= yaml =

# Principals

A [*principal*][principal] in the Vanadium framework is simply a public and
private [key pair]. It has a set of human-readable names bound to it
using public-key certificate chains, called [*blessings*][blessing].
All Vanadium processes act on behalf of a principal and are authorized by
other processes based on the blessing names bound to the principal.

For example a principal _Alice_ may have the blessings `alice` and
`bob:houseguest` bound to it. A process running on behalf of Alice
may authenticate to others as either `alice` or `bob:houseguest` or both.

A principal and the set of blessings bound to it, are together
referred to as _credentials_.  The [basics tutorial] demonstrated that
a client and server can talk to each other if they run with the _same
credentials_.

To reiterate this, create two principals Alice and Bob with blessings
`alice` and `bob` bound to them respectively:

<!-- @makeAliceAndBob @test @completer -->
```
$V_BIN/principal create --overwrite $V_TUT/cred/alice alice
$V_BIN/principal create --overwrite $V_TUT/cred/bob bob
```

Run the server with Alice's credentials (i.e, authenticate as `alice`):

<!-- @runServerAsAlice @test @sleep -->
```
kill_tut_process TUT_PID_SERVER
$V_TUT/bin/server \
    --v23.credentials $V_TUT/cred/alice \
    --endpoint-file-name $V_TUT/server.txt &
TUT_PID_SERVER=$!
```
then make a request as Alice:

<!-- @runClientAsAlice @test -->
```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/alice \
    --server `cat $V_TUT/server.txt`
```

then make a request as Bob (it should fail):

```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/bob \
    --server `cat $V_TUT/server.txt`
```

The reason the request from Alice succeeds and that from Bob
fails is because of the Default Authorization Policy used by
the server.

![Alice's request to the server succeeds, but Bob's request fails](/images/tut/security01-alice-succeeds-bob-fails.svg)

# Default authorization policy

In the absence of any explicit indications by the developer, Vanadium
services use the following default policy:

> *Servers authorize clients if the client's blessings are an extension of the server's,
> or the server's blessings are an extension of the client's.*

For example, a server that presents the blessing `alice:hometv` to
clients will authorize only clients that present either `alice`, or `alice:hometv`,
 or `alice:hometv:app`, etc. to the server.

In the sample run above, _Alice the server_ recognizes _Alice the client_ as herself
(same principal and blessing), and therefore grants access under the default authorization
policy.

Under the same policy, Alice's server rejects Bob's request, as neither `alice`
nor `bob` is an extension of the other.

# Blessings

Per the default authorization policy, Bob's request to Alice's server would
succeed if he had a blessing of the form `alice:<something>`. Such a blessing
can be created by Alice by _blessing_ Bob.

A principal can _bless_ another principal by extending a subset
of its own blessings and create a blessing for the other principal.
This operation can be carried out by the `principal` command:

<!-- @aliceBlessBobAsFriend @test @completer -->
```
$V_BIN/principal bless \
    --v23.credentials $V_TUT/cred/alice \
    --for=24h $V_TUT/cred/bob friend:bob | \
        $V_BIN/principal \
            --v23.credentials $V_TUT/cred/bob \
            set forpeer - alice
```

In the first invocation of `principal`, Alice creates a blessing for Bob
named `alice:friend:bob`. A blessing can carry an expiry time (along with
other restrictions, explained in subsequent tutorials) after which it is
no longer valid.

The second invocation takes that blessing off the pipe and
stores it for later use by Bob when talking to Alice's server.

{{# helpers.info }}
  # Alice and Bob would typically be on different devices.

  A blessing does not contain any private keys and is useful only to
  the one blessed, so it could be transferred via email without
  compromising its purpose.

  Blessings are transferred via pipes in this tutorial for educational
  brevity.  Later tutorials will show (with more coding details) how a
  blessing can directly accompany the request that the blessing
  authorizes.

{{/ helpers.info }}

![Alice blesses Bob as a friend](/images/tut/security02-alice-blesses-bob.svg)

Because Bob has stored the new blessing with his credentials,
the same request from Bob that previously failed now succeeds:

<!-- @clientAsBob @test -->
```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/bob \
    --server `cat $V_TUT/server.txt`
```

![Bob's request to the server succeeds](/images/tut/security03-alice-bob-succeed.svg)

We're done with the server now.

<!-- @killServer @test -->
```
kill_tut_process TUT_PID_SERVER
```

# Steps to authentication

In Vanadium, a remote procedure call is a multi-step process
authentication based on blessings:

* The client knocks on the door with an initial, ping-like request
  that reveals little to the not-yet trusted server.

* The server responds with one or more blessings - the server is
  saying _who it is_.  A blessing is an identity.

  Above, the server sends its blessing `alice`.  This allows the
  client to establish the server's identity before revealing any
  further information about the client's intent.

* Based on the received blessings, the client choses which (if any) of
  its blessings to reveal to the server, and sends them along with
  its service request.

  Above, Bob's client sent back two blessings: `bob` and
  `alice:friend:bob`.  The former is always sent, and the latter is
  sent to any server identifying itself as `alice`.

* If the server authorizes the request for the given blessings, it
  executes the service call and returns results.

  Above, the blessing `alice:friend:bob` (originally generated by
  alice and stored by bob) has authorization, so Bob gets his fortune.

# Summary

* Alice and Bob have been established as [principals][principal].

* Alice ran a server, which Bob couldn't talk to.  Without changing
  anything about the runner server, Alice [blessed][blessing] Bob and
  Bob could talk to Alice's server.

* The default authorization policy lets anyone that Alice blesses talk
  to her without restriction.

* The `principal` program reports credentials data
  * `principal dump` summarizes credentials.
  * `principal get` drills into credential details.
  * `principal dumpblessings` reports the detailed [certificate]
    chains that comprise blessings.

# Appendix:  Reporting credentials

{{# helpers.info }}

Feel free to skim this, and refer back to it from later tutorials as
the need arises.

{{/ helpers.info }}

This section reviews commands that display data from a principal's
credentials.  The `principal` subcommands shown here are handy to use
in all subsequent tutorials.


## Alice

The `dump` command summarizes a principal's credentials:

<!-- @principalAliceDump @test -->
```
$V_BIN/principal \
    --v23.credentials $V_TUT/cred/alice \
    dump
```

This results in something like:

{{# helpers.codeoutput }}
Public key : 0a:e3:61:0e:3e:ec:9c:ce:ed:04:c1:c6:58:78:28:a8
---------------- BlessingStore ----------------
Default blessings: alice
Peer pattern                   : Blessings
...                            : alice
---------------- BlessingRoots ----------------
Public key                                      : Pattern
0a:e3:61:0e:3e:ec:9c:ce:ed:04:c1:c6:58:78:28:a8 : [alice]
{{/ helpers.codeoutput }}

This output and its individual components are described below.

### Public key

The `Public key` line shows the public half of Alice's public/private
key pair.  Isolate it as follows:

<!-- @principalAliceGetPublicKey @test -->
```
$V_BIN/principal \
    --v23.credentials $V_TUT/cred/alice \
    get publickey --pretty
```

### Blessings presented as server

The `Default blessings` line shows the blessings that the principal
will use when it _acts as a server_ responding to a client.

These blessings will be revealed to all clients of the server,
regardless of the blessings presented by the client.

There can be more than one blessing; a principal can play multiple
roles - phone, music player, email client, etc.

Examine them as follows:

<!-- @principalAliceGetDefault @test -->
```
$V_BIN/principal \
    --v23.credentials $V_TUT/cred/alice \
    get default -names
```

### Blessings presented as a client

Below the headings `Peer pattern | Blessings` are the blessings used
when the principal _acts as a client_, sending its credentials to a
server.

This is a _peer map_.  The client takes the blessing that came from
the server, matches it to [patterns] on the left, and responds to the
server using the blessings on the right.

Examine the map as follows:
<!-- @principalAliceGetPeerMap @test -->
```
$V_BIN/principal \
    --v23.credentials $V_TUT/cred/alice \
    get peermap
```

The pattern `...` matches on all servers, so the name `alice` (the
name associated with her [self-blessing]) is provided to all servers.

### Recognized roots

The `BlessingRoots` section displays all
[root public keys][blessing root] recognized by this principal.  The
blessing name patterns following a given public key are trusted if
they are presented by a principal with the given key.

Report just the recognized roots with:
<!-- @principalAliceGetRoots @test -->
```
$V_BIN/principal \
    --v23.credentials $V_TUT/cred/alice \
    get recognizedroots
```

There's only one key here because currently `alice` only recognizes
herself.

## Bob

The situation for Bob is slightly different:

<!-- @principalBobDump @test -->
```
$V_BIN/principal \
    --v23.credentials $V_TUT/cred/bob \
    dump
```
Example output:

{{# helpers.codeoutput }}
Public key : 8e:03:13:7b:f1:57:28:11:87:f0:e8:90:3b:5c:5f:fe
---------------- BlessingStore ----------------
Default blessings: bob
Peer pattern                   : Blessings
...                            : bob
alice                          : alice:friend:bob
---------------- BlessingRoots ----------------
Public key                                      : Pattern
0a:e3:61:0e:3e:ec:9c:ce:ed:04:c1:c6:58:78:28:a8 : [alice]
8e:03:13:7b:f1:57:28:11:87:f0:e8:90:3b:5c:5f:fe : [bob]
{{/ helpers.codeoutput }}

### Public key

Critically, Bob has a different public key from Alice:

<!-- @comparePublicKeys @test -->
```
keyAlice=`$V_BIN/principal \
    --v23.credentials $V_TUT/cred/alice \
    get publickey --pretty`
keyBob=`$V_BIN/principal \
    --v23.credentials $V_TUT/cred/bob \
    get publickey --pretty`
echo -e "alice   $keyAlice\n  bob   $keyBob"
```

### Blessings presented as server

Bob will report himself to clients as `bob`:

<!-- @principalBobGetDefault @test -->
```
$V_BIN/principal \
    --v23.credentials $V_TUT/cred/bob \
    get default -names
```

### Blessings presented as a client

Bob's peer map shows that he has stored a blessing `alice:friend:bob`
that is sent only to servers that have identified themselves as
`alice`.

<!-- @principalBobGetPeerMap @test -->
```
$V_BIN/principal \
    --v23.credentials $V_TUT/cred/bob \
    get peermap
```

Bob also sends his [self-blessing] `bob` to everyone.

### Recognized roots

Bob, as a side effect of accepting a blessing from Alice, *remembers*
Alice's public key and will trust a principal claiming to be
`alice` only if it presents that public key.

<!-- @principalBobGetRoots @test -->
```
$V_BIN/principal \
    --v23.credentials $V_TUT/cred/bob \
    get recognizedroots
```

On the other hand, Alice's principal at this point has no record of
Bob's public key.  Her server honors Bob's request because Bob
presents a blessing rooted at her own public key.

## Blessing details

The following command extracts the blessings Bob should use with Alice
and prints them in detail:

<!-- @principalBobDumpBlessings @test -->
```
$V_BIN/principal \
    --v23.credentials $V_TUT/cred/bob \
    get forpeer alice | \
         $V_BIN/principal dumpblessings -
```

Example output:

{{# helpers.codeoutput }}
Blessings          : bob#alice:friend:bob
PublicKey          : 8e:03:13:7b:f1:57:28:11:87:f0:e8:90:3b:5c:5f:fe
Certificate chains : 2
Chain #0 (1 certificates). Root certificate public key: 8e:03:13:7b:f1:57:28:11:87:f0:e8:90:3b:5c:5f:fe
  Certificate #0: bob with 0 caveats
Chain #1 (2 certificates). Root certificate public key: 0a:e3:61:0e:3e:ec:9c:ce:ed:04:c1:c6:58:78:28:a8
  Certificate #0: alice with 0 caveats
  Certificate #1: friend:bob with 1 caveat
    (0) security.unixTimeExpiryCaveat(1419279349 = 2014-12-22 12:15:49 -0800 PST)
{{/ helpers.codeoutput }}

Alice's public key is at the root of a
[_certificiate chain_][certificate] corresponding to the blessing
`alice:friend:bob`.

### Names

From the `dumpblessings` output, isolate
[blessing names][blessing name] (the names presented to a server) with

<!-- @principalBobGetForPeerName @test -->
```
$V_BIN/principal \
    --v23.credentials $V_TUT/cred/bob \
    get forpeer -names alice
```

This shows that Bob will present `bob` and `alice:friend:bob`.


### Root keys

Examine [root keys][blessing root] with
<!-- @principalBobGetForPeerRoots @test -->
```
$V_BIN/principal \
    --v23.credentials $V_TUT/cred/bob \
    get forpeer -rootkey=alice:friend:bob alice
```

That command answers the question

> _Find the blessings `bob` will present to `alice`, and among them find
> the blessing named `alice:friend:bob` and report the public key of
> the principal it came from._

In this case, the output should match Alice's public key:

<!-- @echoAlicesKey @test -->
```
echo $keyAlice
```

### Caveats

Examine [_caveats_][caveat] with
<!-- @principalBobGetForPeerCaveats @test -->
```
$V_BIN/principal \
    --v23.credentials $V_TUT/cred/bob \
    get forpeer -caveats=alice:friend:bob alice
```

That command answers the question

> _Find the blessings `bob` will present to `alice`, and among them find
> the blessing named `alice:friend:bob` and report its caveats._

This shows that Bob's blessing from Alice will expire in about 24h.
That expiration was set using the `--for` flag in the `bless` command
[above](#blessings).

Caveats will be discussed in more depth in the [caveats tutorial].

[basics tutorial]: /tutorials/basics.html
[blessing name]: /glossary.html#blessing-name
[blessing root]: /glossary.html#blessing-root
[blessing]: /glossary.html#blessing
[caveat]: /glossary.html#caveat
[caveats tutorial]: /tutorials/security/first-party-caveats.html
[certificate]: /glossary.html#certificate
[key pair]: http://en.wikipedia.org/wiki/Public-key_cryptography
[patterns]: /glossary.html#blessing-pattern
[principal]: /glossary.html#principal
[self-blessing]: /glossary.html#self-blessing
