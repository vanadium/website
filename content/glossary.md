= yaml =
title: Glossary
toc: true
= yaml =

# Access list

An access list describes which [blessing names](#blessing-name) should be
granted access to a particular object or method.

An access list has an _In_ list of [blessing patterns](#blessing-pattern) that
grants access to all blessing names that are matched by one of the patterns,
and an optional _NotIn_ list that specifies exclusions from the _In_ list.

For example, an access list with the _In_ list {`alice:family`} and _NotIn_
list {`alice:family:uncle`} is matched by principals with blessing names
`alice:family`, `alice:family:friend`, but NOT `alice`, `alice:friend`,
`alice:family:uncle`, `alice:family:uncle:spouse`, and so on.

See also: [Blessing patterns](#blessing-pattern) for the semantics of pattern
matching, [Security Concepts].

# Agent

Agent is a utility for serving [credentials](#credentials) to applications
analogous to an [ssh-agent]. The agent is used to protect private keys from
vulnerabilities in the application.  The private key is kept encrypted on disk
and unencrypted in the memory of the agent process.

Application processes that are descendants of the agent process can use the
credentials (e.g., sign a message using the private key) by making requests to
the agent process over inter-process communication channels.

See also: [Security Concepts].

# Blessing

A blessing is a binding of a human-readable [name](#blessing-name) to a [principal](#principal),
valid under some [caveats](#caveat), given by another principal.

Principals are authorized for operations based on these names.

The binding between the name, the principal and the caveats is cryptographically
secured via a chain of [certificates](#certificate). A blessing bound to one
principal cannot be used by another. Thus, the theft of blessings does not
present a security risk.

For example, a principal _Alice_ (with the key pair <code>(P<sub>alice</sub>,
S<sub>alice</sub>)</code>) can bind the name `allie` (or any other name of her
choosing) to herself with a self-signed certificate that binds the name `allie`
to <code>P<sub>alice</sub></code>, with the caveat that this name can only be
used for "read" operations. Since the blessing is based on a self-signed
certificate, it is referred to as a [_self-blessing_](#self-blessing).

When one principal blesses another, they do so by chaining a new certificate
to one of their existing blessings. For example, consider the following two
certificates:

1. One that binds the __extension__ `friend` to the public key <code>P<sub>bob</sub></code>
   with the caveat "use only between 9am and 5pm" _chained to_
2. The `allie` certificate mentioned above.

Both certificates chained together represent a blessing that binds the name
`allie:friend` to _Bob_, but only for "read operations, between 9am and 5pm"
(all the caveats in all the certificates in the chain).

_Bob_ can then bless _Carol_ with the name `allie:friend:colleague` by chaining
a new certificate, signed by <code>S<sub>bob</sub></code> to his `allie:friend`
blessing.

See also: [Security Concepts].

# Blessing name

A blessing name is the _human readable_ name extracted from a
[blessing](#blessing).  Principals are typically authorized based on the
blessing names bound to them.

For example, say a principal _Carol_ wishes to invoke the `Read` method on a
service run by a principal _Alice_. The authorization decision is made after a
sequence of steps:

1. _Carol_ presents a set of blessings (bound to her public key) to _Alice_.
2. _Alice_ looks at each presented blessing and discards those which have
   [caveats](#caveats) that are not met in context of the method being invoked (or those which are not [recognized](#blessing-root)).
3. _Alice_ then looks at the names of the remaining blessings and decides
   whether _Carol_ is authorized to invoke the method or not based on the name.

Two principals can have the same blessing name bound to them,
allowing them to share authorization without sharing each other's secret
private key.

See also: [Security Concepts].

# Blessing pattern

A blessing pattern is a "pattern" that is matched by either a specific
[blessing name](#blessing-name) or the blessing name and all its
[extensions](#blessing).

The pattern `<b>:$` is matched by the blessing name `<b>`, while the pattern `<b>`
is matched by `<b>` and all its extensions.

For example, the pattern `alice:houseguest` will be matched by the blessing
name `alice:houseguest`, `alice:houseguest:bob`, `alice:houseguest:bob:friend`
but not `alice:colleague`, `alice:houseguest2` or prefixes of the pattern like
`alice` (for example `alicea` or `aliceb`). The pattern `alice:houseguest:$`
would be matched only by the exact blessing name `alice:houseguest`.

See also: [Security Concepts].

# Blessing root

The root of a blessing is the public key of the first certificate in the
certificate chain of the blessing.

A blessing is _recognized_ by an application if and only if the application
considers the root of the blessing as being authoritative on the corresponding
[blessing name](#blessing-name).

For example, one application may recognize the root
<code>P<sub>alice</sub></code> as an authority on blessings matching the
pattern `allie`, such as `allie` and `allie:friend`.  Other applications may
not do so.  Thus, when a blessing with the root <code>P<sub>alice</sub></code>
is presented to them, they will discard this blessing when extracting [blessing
names](#blessing-name).

See also: [Security Concepts].

# Caveat

Caveats are conditions placed on a [blessing](#blessing) to restrict the
validity of a [blessing name](#blessing-name). For example, caveats may restrict
the time duration for which the blessing name can be used, or the set of peers
that can be communicated with or the type of operations that can be performed.

When two principals communicate via an [RPC](#remote-procedure-call-rpc-), they
validate all the caveats in the blessings presented by the peer. In a
client-server setting, the client validates caveats on the blessings presented
by the server and vice-versa.

Caveats are of two kinds -- first-party and third-party.  First-party caveats
are validated entirely by the party making an authorization decision on the
blessings presented by the remote end.

[Third-party caveats](#third-party-caveat) are validated by the specific
third party mentioned in the caveat. The party making the authorization
decision expects a proof of validity (i.e., a [Discharge](#discharge)) for the
caveat from the third party.

See also: [Security Concepts].

# Certificate

A certificate is an object consisting of a human-readable string name,
a public key, a list of [caveats](#caveat), and a digital signature over
its contents.

Certificates can be _chained_ to form a [blessing](#blessing). The first
certificate in the chain is _self-signed_, i.e., it is signed using the private
counterpart of the public key mentioned in the certificate and is referred to
as the _root certificate_.

All other certificates in the chain are signed by the private counterpart of
the public key mentioned in the previous certificate in the chain.

See also: [Security Concepts].

# Client

A client is the caller-side of an [RPC](#remote-procedure-call-rpc-).  Clients
invoke methods on [servers](#server).

# Credentials

Credentials encompass a [principal](#principal) (i.e., a public-private key
pair), the set of [blessings](#blessing) bound to that principal, and the set
of recognized [blessing roots](#blessing-root).

An application process retrieves its credentials from a directory containing
this data, or from an [agent](#agent) that holds this data (including the
private key of the principal) safely.

# Discharge

A discharge is a proof of validity of a [third-party
caveat](#third-party-caveat) issued by the third party mentioned in the
caveat. It is cryptographically tied to the particular caveat.

A discharge may have [caveats](#caveat) of its own that limit the
validity of the discharge.

A discharge can be cached and reused, so it's not necessarily true
that every attempt to use a blessing will incur the cost of obtaining
a discharge.

Discharges may expire, but the expiration time is typically broad
enough to allow for clock skew.

# Discharger

A server that must be consulted to mint a [discharge](#discharge) for
a caveat. A blessing is valid only if _all_ of its
[third-party caveats](#third-party-caveat) are discharged.

See also: [Security Concepts].

# Endpoint

An Endpoint is an encoding of all the information required to securely contact
a [server](#server).  Among other things, this includes the network address of
the server, e.g.,`<IP address>:<port>` (tcp), or `<MAC address>` (bluetooth).

# Identity provider

An identity provider is a [principal](#principal) that signs [root
certificates](#certificate) of [blessings](#blessing) with a fixed name.

For an identity provider to be useful, an application must use
[credentials](#credentials) that [recognize](#blessing-root) its public key as
an authority on blessings extended from its name.

For example, _Popular Corp_ could be an identity provider with public key
<code>P<sub>popularcorp</sub></code> and name `popularcorp`. It could bless
other principals with the name `popularcorp:<username>`. However, this identity
provider will only be useful to other applications that recognize
<code>P<sub>popularcorp</sub></code> as an authoritative key on blessing names
beginning with `popularcorp:`.

Root certificates (and thus identity providers) are recognized only for
blessings matching a specific [pattern](#blessing-pattern).  For example, an
application might recognize the root <code>P<sub>popularcorp</sub></code> for
blessings that match the pattern `popularcorp` and not for blessings that match
`othercorp`. This prevents [certificate forging] where one recognized identity
provider can issue certificates for an entity that is normally managed by
another identity provider.

Companies, schools, or other public agencies could become _identity providers_
and application [credentials](#credentials) will be configured to recognize
some subset of these. For example, services run for general consumption might
trust a Google-run blessing service, while services run within a corporate
setting would only recognize blessings whose root was a key owned by the
corporation.

See also: [Security Concepts].

# Mount table

A mount table is a [server](#server) that associates [object
names](#object-name) with ([endpoint](#endpoint), [suffix](#suffix)) pairs.
The endpoint identifies the server that hosts the named object, and the suffix
is used to locate the object within the server.

The process of associating a name (aka "mount point") with the (endpoint,
suffix) pair of an object is called "mounting".

Since the mount point is itself an object (on which the `Mount`
[RPC](#remote-procedure-call-rpc-) can be invoked), it can be mounted on other
mount points. This allows for the creation of a hierarchy of names, a
[namespace](#namespace) of objects.

See also: [Naming Concepts][naming-concepts].

# Namespace

A directed graph made up of [mount tables](#mount-table) that create a
hierarchy of [object names](#object-name).

A namespace may contain loops (it is not a DAG).

# Object name
###### Also called: Name

An object name is a human-readable name of an object that exports methods on
which [RPCs](#remote-procedure-call-rpc-) can be made.

Object names are _resolved_ to a set of ([endpoint](#endpoint),
[suffix](#suffix)) pairs via [mount tables](#mount-table). Invoking an RPC on an
object implies sending the RPC to one of the pairs obtained by _resolving_ the
object name.

For example, the object name `alice/calendar/today` might _resolve_ to the
[endpoint](#endpoint) of Alice's calendar server and the suffix `today`.  The
object might export methods `AddAppointment` and `RemoveAppointment`, which are
invoked to manage Alice's calendar.

See also: [Naming Concepts][naming-concepts].

# Permissions

Permissions are maps from string tags (like "Read" or "Admin") to [Access
Lists](#access-list) specifying the blessings required to invoke methods with
that tag.

See also: [Security Concepts].

# Principal

A principal is a public and private [key pair].

Every [RPC](#remote-procedure-call-rpc-) is executed on behalf of a principal.
To encourage security, different processes and certainly processes on different
devices run as different principals - each with their own private key. The
private key should ideally be in secure storage such that it cannot be stolen
from the device on which the application is being run.

Applications should never share their private key or transmit it on the wire.
Only public keys and [blessings](#blessing) should be transmitted. Multiple
[blessings](#blessing) can be bound to a single principal.

See also: [Security Concepts].

# Remote Procedure Call (RPC)

Remote procedure calls enable communications between processes by presenting
an API based on function calls. The caller of an RPC is known as the
[client](#client) and the receiver that implements the RPC is known as the
[server](#server).  Clients invoke methods implemented on the server, which is
identified by its [object name](#object-name).

See also: [RPC concepts][rpc-concepts].

# Self-blessing

A [blessing](#blessing) who's certificate chain has only one certificate,
necessarily self-signed, since if it had been signed by another
principal it would not be a single entry chain.

A self-blessing is the starting point to issuing blessings to other
principals.

# Server

A server is the receiver-side of an [RPC](#remote-procedure-call-rpc-).
Servers implement methods that are invoked by [clients](#client).

The term server is also used to refer to the process that hosts objects and
dispatches RPC requests to the methods implemented by those objects.

# Suffix

A suffix is the trailing portion of an [object name](#object-name) used to
identify the object within a server.

For example, the object name `alice/calendar/today` may be hosted by a
[server](#server) that hosts all objects with the prefix `alice/calendar`.  In
that case, the [RPC](#remote-procedure-call-rpc-)
`alice/calendar/today.AddAppointment()` will be directed to this server and the
suffix `today` will be used by the server to identify the object.

# Third-party caveat

_Third-party caveats_ are [caveats](#caveat) wherein the burden of validation
is pushed to a specific _third party_ that is different from the request
recipient.

A blessing with a third-party caveat is considered valid only when accompanied
by a [discharge](#discharge) (proof of validity) issued by the specific third
party mentioned in the caveat. The third party validates the caveat before
granting or denying a discharge.

Examples of third-party caveats include _revocation_ caveats that are
discharged by a specific revocation service if and only if the blessing has
not been revoked, _proximity_ caveats that are discharged by a proximity
service if and only if the requester satisfies the proximity constraints
mentioned in the caveat, and _audit_ caveats  that are discharged by an
auditing service only after updating the audit log.

It is the responsibility of the wielder of a blessing to fetch discharges for
all third-party caveats present on the blessing. The wielder may cache
discharges for as long as they are valid.

See also: [Security Concepts].

# v23

The [atomic number of Vanadium][vanadium-element] is 23, which is the
inspiration behind the `v23` shorthand for Vanadium.

# vrpc

The `vrpc` command line tool sends and receives
[RPCs](#remote-procedure-call-rpc-).  It is used as a generic [client](#client)
to interact with any [server](#server).

# Vanadium Definition Language (VDL)

VDL describes the API for interfaces provided by objects. This includes the set
of methods that can be invoked via an [RPC](#remote-procedure-call-rpc-), their
arguments and return types.  These interfaces are described in `.vdl` files. The
`vdl` command-line tool generates language-specific interfaces for these APIs.

See also: [VDL specification][vdl-spec].

# Vanadium Object Marshaling (VOM)

VOM is the data serialization format used in Vanadium.  It enables the
encoding and decoding of typed values across different programming languages,
e.g. Go and Java.

See also: [VOM specification][vom-spec].

# WebSocket Proxy (WSPR)

A server (usually called WSPR, pronounced *whisper*) allows JavaScript
running in a web browser or Node.js to communicate with a Vanadium system.
WSPR proxies the Vanadium world behind a WebSocket interface.

A JavaScript app uses a Node.js module that implements a WebSocket front-end
to WSPR. WSPR accepts requests from the app over the WebSocket, sends them on
as conventional Vanadium RPCs, and returns the responses to the JavaScript app
via WebSocket.

WSPR as a concept will move from a freestanding server into a browser
extension, and ultimately become native to browsers.

[naming-concepts]: /concepts/naming.html
[rpc-concepts]: /concepts/rpc.html
[vdl-spec]: /designdocs/vdl-spec.html
[vom-spec]: /designdocs/vom-spec.html
[gob]: http://golang.org/pkg/encoding/gob/
[key pair]: http://en.wikipedia.org/wiki/Public-key_cryptography
[certificate forging]: https://www.linshunghuang.com/papers/mitm.pdf
[ssh-agent]: http://en.wikipedia.org/wiki/Ssh-agent
[vanadium-element]: http://en.wikipedia.org/wiki/Vanadium
[Security Concepts]: /concepts/security.html
