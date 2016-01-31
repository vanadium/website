= yaml =
title: The Suffix - Part I
layout: tutorial
wherein: for the first time you build a server with multiple services and use the server's namespace to address them. This is an advanced tutorial.
prerequisites: {completer: suffix-part1, scenario: c}
sort: 33
toc: true
= yaml =

# Introduction

In an earlier tutorial, a fortune server was
[mounted in a table with the name `fortuneAlpha`][fortuneAlpha].

Since that server contained only one service, clients needed nothing
more than that name, as seen in the mount table, to start using the
service.

If a server contains _multiple_ services, a __suffix__ is needed to
select one.  _A mount table doesn't know about suffixes directly._  A server
encapsulates that knowledge in its dispatcher.

Let's build an example.

# Requirements

Your company, _Prophecies Inc_, needs a server to support its team of
prophetic _consultants_ - Cassandra, Nostradamus, etc.  Each consultant
needs its own data and customers.

 1. _Many services_: To support hiring new consultants, the server
    must be able to create fortune services on the fly, each with its
    own set of fortunes.

 1. _Discovery_: Customers must be able to discover all the available
    services.

To do this, we'll use a custom dispatcher.

One thing we _won't_ need is a new service implementation.
The one we have can be used as is.


## New dispatcher

Recall the basic program layout:

![](/images/tut/basic-program-1auth.svg)

The dispatcher owns all the services in a server.  All previous
tutorials used servers with just one service, so a default dispatcher
was used - its only job was to figure out which method to invoke on
the single service.

In this tutorial, we need a custom dispatcher that maps from
_suffixes_ to services.

Examples below will show a client asking for a fortune from a service,
named `prophInc/cassandra`.  The resolution process will
determine that `prophInc` is a name associated with a server
endpoint in a mount table (exactly like [`fortuneAlpha`][fortuneAlpha]
was earlier), and that `cassandra` is a suffix.

This suffix `cassandra` is ultimately passed to the `Lookup` method in
a [dispatcher interface].  `Lookup` accepts a suffix and returns a
service, and the authorizer that guards it.

The examples will also show that `cassandra` and all other service
names under `prophInc` are discoverable in the namespace.

Here's an implementation satisfying the _service_ requirements:

<!-- @newDispatcher @test @completer -->
```
 cat - <<EOF >$V_TUT/src/fortune/server/util/dispatcher.go
package util

import (
  "errors"
  "strings"
  "sync"
  "fortune/ifc"
  "fortune/service"
  "v.io/v23/context"
  "v.io/v23/rpc"
  "v.io/v23/security"
)

type myDispatcher struct {
  mu sync.Mutex
  registry map[string]interface{}
}

func (d *myDispatcher) Lookup(
    _ *context.T, suffix string) (interface{}, security.Authorizer, error) {
  if strings.Contains(suffix, "/") {
    return nil, nil, errors.New("unsupported service name")
  }
  auth := MakeAuthorizer()
  d.mu.Lock()
  defer d.mu.Unlock()
  if suffix == "" {
    names := make([]string, 0, len(d.registry))
    for name, _ := range d.registry {
      names = append(names, name)
    }
    return rpc.ChildrenGlobberInvoker(names...), auth, nil
  }
  s, ok := d.registry[suffix]
  if !ok {
    // Make the service on first attempt to use.
    s = ifc.FortuneServer(service.Make())
    d.registry[suffix] = s
  }
  return s, auth, nil;
}

func MakeDispatcher() rpc.Dispatcher {
  return &myDispatcher {
    registry: make(map[string]interface{}),
  }
}
EOF
```

__Code walk__

The server's `root` object is accessed with an empty suffix (_""_). In
this example, the `root` object is a [ChildrenGlobber] service that makes
the fortune service names discoverable in the server's namespace.

This dispatcher uses the suffix as a key in a string-to-service map
called `registry`.  If the map lookup fails, _a new service is created
on the fly_, and stored in the map using the suffix.

The service object associated with the suffix is returned to the caller
of `Lookup`.

`Lookup` must also return an authorizer.  A dispatcher's job is to
determine which authorizer to use with a given service. In this example,
we use the [default authorizer] for simplicity.

Since any server should support concurrent access, its service map should
be protected my a mutex.

# Try it

## Principal

In this example, we run the client and the server as the same [principal].
We can re-use the `tutorial` principal from the basics tutorial.

## Start the server

Fire up the server with the new dispatcher code:

<!-- @buildServer @test @completer -->
```
go install fortune/server
```

<!-- @runServer @test @sleep -->
```
kill_tut_process TUT_PID_SERVER
$V_TUT/bin/server \
    --v23.credentials $V_TUT/cred/basics \
    --endpoint-file-name $V_TUT/server.txt &
TUT_PID_SERVER=$!
```

## Hire Cassandra

Try to run a client as Cassandra:

{{# helpers.warning }}
Expect it to fail.
{{/ helpers.warning }}

<!-- @firstTry -->
```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/basics \
    --server `cat $V_TUT/server.txt`
```

The error is _Method does not exist: Get_. This is because the root
object, i.e. the one associated with an empty _suffix_, does not implement
the Fortune interface.

To get past this, specify a _suffix_:

<!-- @secondTry -->
```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/basics \
    --server `cat $V_TUT/server.txt`/cassandra
```

That works.  This time the server was specified with the suffix
`cassandra`.

Likewise, the client should be able to write to that service:

<!-- @writingWorksToo -->
```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/basics \
    --server `cat $V_TUT/server.txt`/cassandra \
    --add 'Do not visit Sparta!'
```

But how would customers know that the `cassandra` service exists? The
answer is in the server's namespace.

The server's namespace is just like the mount table namespace. It allows
the server to publish the name of the services that it hosts. In this
example, this is accomplished by the [ChildrenGlobber] service at the
server's `root`.

[ChildrenGlobber] is covered in more details in the [Globber] tutorial.

<!-- @globServer -->
```
$V_BIN/namespace \
    --v23.credentials $V_TUT/cred/basics \
    --v23.namespace.root `cat $V_TUT/server.txt` \
    glob "*"
```

Let's insert a table to make service specifications easier to read.

# Mount it

Start a mount table and save it in
[`$V23_NAMESPACE`][v23_namespace]:

<!-- @startMountTable @test @sleep -->
```
PORT_MT=23000  # Pick an unused port.
kill_tut_process TUT_PID_MT
$V_BIN/mounttabled \
    --v23.credentials $V_TUT/cred/basics \
    --v23.tcp.address :$PORT_MT &
TUT_PID_MT=$!
export V23_NAMESPACE=/:$PORT_MT
```

Restart the fortune server to publish itself in the mount table at the
name `prophInc`:

<!-- @runServer2 @test @sleep -->
```
kill_tut_process TUT_PID_SERVER
$V_TUT/bin/server \
    --v23.credentials $V_TUT/cred/basics \
    --service-name prophInc \
    --endpoint-file-name $V_TUT/server.txt &
TUT_PID_SERVER=$!
```

Now add a new fortune via a mount table lookup:

<!-- @writeViaTable @test -->
```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/basics \
    --server prophInc/cassandra \
    --add 'Troy is doomed!'
```

It's this last usage that makes the term __suffix__ clear.

The mount name `prophInc` is followed by the suffix `cassandra` to
specify which service to access in the server.

Customers can discover the service names via the mount table:

<!-- @globMounttable -->
```
$V_BIN/namespace \
    --v23.credentials $V_TUT/cred/basics \
    glob "prophInc/*"
```

The server's namespace transparently extends the mount table's namespace.

# Exercises

## Add other services

Create another service for nostradamus and watch it appear in the
namespace next to cassandra.

<!-- @createNostradamusService @test -->
```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/basics \
    --server prophInc/nostradamus

$V_BIN/namespace \
    --v23.credentials $V_TUT/cred/basics \
    glob "prophInc/*"
```

# Cleanup

<!-- @cleanup @test -->
```
kill_tut_process TUT_PID_SERVER
kill_tut_process TUT_PID_MT
unset V23_NAMESPACE
```

# Summary

* Servers can contain multiple services, identified by a __suffix__.

* These services can be published in the server's namespace.

[fortuneAlpha]: /tutorials/naming/mount-table.html#mounting
[default authorizer]: /tutorials/security/principals-and-blessings.html#default-authorization-policy
[dispatcher interface]: https://godoc.org/v.io/v23/rpc#Dispatcher
[v23_namespace]: /tutorials/naming/mount-table.html#the-namespace-variable
[Globber]: /tutorials/naming/globber.html
[ChildrenGlobber]: /tutorials/naming/globber.html#introduction
