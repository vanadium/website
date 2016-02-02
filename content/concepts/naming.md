= yaml =
title: Naming
sort: 2
toc: true
= yaml =

The Vanadium naming system enables discovery of devices, regardless of their
physical locations - with or without an internet connection.

# Object names

Vanadium names, usually abbreviated to "_names_" refer to objects.

Objects implement RPC methods.  In other words, methods are invoked on
object names. The basic primitive is thus:

    name.method(args) -> results

For example, if the name `/host:8080/a/y/foo.jpg` represents a JPEG file, then
`/host:8080/a/y/foo.jpg.Get()` will return the contents of that file.

Object names are hierarchical consisting of components separated by slashes (/).
Glob patterns, as on Unix, are restricted to matching name components.

Object names are resolved to obtain an _object address_. The underlying RPC
protocol uses object addresses to establish communication with the process
containing the named object prior to invoking methods on the object. The service
that implements name resolution consists of servers, called _mount tables_, and
a client library called the _namespace_ library.

# Mount tables and namespaces

Mount tables are similar to [DNS][DNS] servers and the namespace library to the
DNS resolver. Similar to DNS and the [Unix filesystem][Unix filesystem], mount
tables may be arranged in layered hierarchies. The resolution process
implemented by the namespace library may iteratively communicate with multiple
mount tables to resolve a single name. This is illustrated in the diagram
below, which shows 6 mount tables. `ns1.v.io:8101` is the _root_ and
`mount table a`, `mount table b` and `mount table c` are _mounted_ in it as `a`,
`b`, `c`. Similarly, `mount table y` and `mount table z` are mounted in
`mount table a` as `y` and `z`. To resolve the name `a/y`, the mount tables on
`ns1.v.io:8101` and `mount table a` must be consulted. To resolve the name
`a/y/foo/bar`, `mount table a/y` must also be consulted, since it serves
mounts made below `y`.

![Example namespace](/images/namespace-generic.svg)

The first element of a name that begins with `/` points to the mount table at
which to begin the resolution. For example, the name `/ns1.v.io:8101/a` starts
resolution with the mount table `ns1.v.io:8101`. These names are called _rooted_
because they need no additional state to perform the resolution, they stand by
themselves.

Names that don't begin with a `/` begin the resolution at a default (or
current) mount table set in the process' namespace library. We
call those names _relative_ because they need the state of the namespace
library to determine how they are resolved.

This is illustrated below, where process `Client 1` has a namespace
that is relative to `ns1.v.io:8101`, its root, and hence can resolve
`a`, `b`, `c`, `a/y`, and `a/z`.

![The view from Client 1](/images/namespace-client1.svg)

In contrast, process `Client 2` with `ns2.v.io:8102` as its root can
resolve only `y` and `z`.

![The view from Client 2](/images/namespace-client2.svg)

The advantage of using a relative namespace is that it can define a context.
For example, for debugging or testing one would set up the namespace to
contain the emulated environment. It is similarly possible to provide context
of nearby devices, or one local to a single machine.

Rooted names can be used to specify an arbitrary server where name resolution
will begin, thus overriding the root of the namespace asked to perform the
resolution. This would allow `Client 2` to refer to `a` as `/ns1.v.io:8101/a`.
The element immediately after the leading slash must be an address, either in
`dnsname:port`, `ipv6:port`, or `ipv4:port` format, or in the Vanadium
[endpoint format][endpoint] that encodes more detailed information about the
server supporting the object (such as protocol versions or a globally unique
id). In all cases they provide a starting point in the [forest][forest] of
namespaces. The object addressed by that element can be another mount table or
the terminal server.

In essence, both rooted and relative names are the same. They represent a walk
through a namespace that consists of a [directed cyclic graph][DCG] of mount
tables ending in a server of the object we're trying to get at. The only
difference with relative names is that we're assuming a "current directory" to
start from as opposed to providing it in the name.

![The leaves are servers, or empty tables](/images/namespace-with-servers.svg)

User-supplied server code that implements RPCs also appears as names in mount
tables. In the diagram above `Server 1` and `Server 2` provide a server called
`srv` that can be accessed as `/ns1.v.io:8101/srv`, which will
resolve to the server hosted by `Server 1` and `/ns1.v.io:8101/a/srv`,
which will resolve to the server hosted by `Server 2`. The mount table at
`ns1.v.io:8101` contains the entry for `Server 1` (as `srv`) and the
mount table at `mount table a` contains the entry for
`Server 2` (also called `srv`). Invoking `/ns1.v.io:8101/srv.Get()`
will result in `Server 1` serving that method, whereas
`/ns1.v.io:8101/a/srv.Get()` will be served by `Server 2`.

The name resolution process is iterative. For `Client 1` to resolve `a/y/bar`,
it will first ask `ns1.v.io:8101` to resolve `a/y/bar`, root
will reply with `mount table a`'s address and `y/bar` as the "unresolved"
portion of the name. `Client 1` will then ask `mount table a` to resolve
`y/bar`, and so on.

If the resolution reaches a leaf server (i.e. one that isn't
a mount table such as `Serve 1` or `Server 2`) and there
are still remaining components to the name, those
"unresolved" components will be passed to the leaf server along with the operation.
Thus the call `/ns1.v.io:8101/srv/foo/bar.Get()` will result in `Server 1` receiving
the RPC `foo/bar.Get()`.

It is possible to create cycles
by creating mount tables that mount themselves through other mount tables. Cycles are
handled by limiting the number of iterations the resolution algorithm will
execute. That is, regardless of whether cycles are present, the
resolution algorithm will bound the number of iterations it executes.

# Mount entries

Our examples above have shown mount tables pointing to other mount tables or to
leaf servers but we haven't said what those pointers are.  They are a set of
equivalent _rooted_ names.  They either specify different addresses for the same
server reachable via different networks (for example IP, IPv6, and Bluetooth),
or they specify addresses for servers that are themselves equivalent either
because they are stateless or because they transparently synchronize their
state.  Thus, we can send an RPC to whichever one is available and that we can
reach.

Normally these rooted names point to the root of the server's namespace and that
is what we have shown in our examples.  However, you can also mount objects
further inside the server's namespace.  In the example above, we could have
mounted `Server 1`s `/foo/bar` onto the name `/ns1.v.io:8101/quux`.  In that
case both `/ns1.v.io:8101/srv/foo/bar` and `/ns1.v.io:8101/quux` would resolve
to the same object. You can use this to create aliases or nicknames for objects,
or to create namespaces that represent some context (like all left handed green
eyed poker players) without creating a specific server to provice such a
grouping.

[DCG]: http://en.wikipedia.org/wiki/Cycle_graph#Directed_cycle_graph
[DNS]: http://en.wikipedia.org/wiki/Domain_Name_System
[forest]: http://en.wikipedia.org/wiki/Forest_(graph_theory)#forest
[Unix Filesystem]: http://en.wikipedia.org/wiki/Unix_File_System
[endpoint]: ../glossary.html#endpoint
