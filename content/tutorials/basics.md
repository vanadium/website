= yaml =
title: Client/Server Basics
layout: tutorial
wherein: you build a fortune teller service and a client to talk to it.
prerequisites: {completer: basics, scenario: a}
sort: 13
toc: true
= yaml =

# Introduction

In the [hello world tutorial], you got a client and server running.

In this tutorial, you'll build a slightly more complex client and
server that will serve as the framework for deeper explorations of
Vanadium _security_ and _service discovery_.

This time, the server code is split into _multiple files_.  The
new code structure lets later tutorials change only the parts that
need to change (e.g., a dispatcher, an authorizer), keeping later
code shorter and clearer. That means doing a few odd things here, like
writing whole code files that, for the time being, only return
__nil__.

This tutorial will otherwise repeat the structure of the [hello world
tutorial].

# Terminology

A Vanadium program can hold any number of __servers__ and __clients__.
When the distinction between these roles isn't important to the
context, a program may be called a __peer__.

A server consists of an __endpoint__, a Vanadium address encapsulating
a hostname, port and other information, and a __dispatcher__.  A
dispatcher maps an incoming request to an __authorizer__ and a
__service__.  The request only makes it to the service if the
authorizer approves.  A dispatcher holds an authorizer
and one or more services.

A client is just stub code, typed to match a particular service
interface, bound to one or more endpoints on the network via a name
(more on that in the [naming tutorials]).  It's the boilerplate
used to contact remote services.

![](/images/tut/basic-program-1auth.svg)

A service has no knowledge of the authorizer protecting it.  Neither
the services nor the authorizers are aware of the dispatcher holding
them.

A typical program will have one server and many clients.  The program
will offer some services to others, and contact other programs in an
effort to provide these services (e.g. a television might contact
several content providers).

A network of programs looks like this:

![](/images/tut/basic-programs-connected.svg)

In this tutorial you'll build two programs.  The first holds one
server and no clients, and - at the risk of overloading terms - is simply
called _the server_.  The second, via similar reasoning, is called
_the client_.

# Define a service

A service is an object that responds to remote procedure calls (RPCs).
The service you'll build here stores and offers up fortunes.

## The interface

The first step to making a Vanadium service is to define it using the
[Vanadium Definition Language][vanadium-definition-language] (VDL).

The following command (read more about `cat` usage
[here][cat command]) will put the VDL in the right spot:

<!-- @defineService @buildjs @test @testui @completer -->
```
mkdir -p $V_TUT/src/fortune/ifc
 cat - <<EOF >$V_TUT/src/fortune/ifc/fortune.vdl
package ifc

type Fortune interface {
  // Returns a random fortune.
  Get() (wisdom string | error)
  // Adds a fortune to the set used by Get().
  Add(wisdom string) error
}
EOF
```

This file defines the [Go] package `ifc` (an abbreviation of
_interface_).  You'll soon define the packages `service`, `util` and
`main`.  Package symbols will be isolated from each other, per Go
namespace rules, making it easier to reason about code dependencies.

## Stub code


Use the `fortune.vdl` you just made to create the file
`fortune.vdl.go`.  This Go code provides stubbed attachment points
that will soon be linked into a client and server.

<!-- @compileInterface @buildjs @test @testui @completer -->
```
VDLROOT=$V23_RELEASE/src/v.io/v23/vdlroot \
    VDLPATH=$V_TUT/src \
    $V_BIN/vdl generate --lang go $V_TUT/src/fortune/ifc
go build fortune/ifc
```

The `go build` command here is just a check for errors. In this
case, the command doesn't create object or executable
files.  In these tutorials, `cat` commands that _create code files_
are immediately followed by commands that attempt compilation as a
quick check for errors.  When the code file created is a main program,
`go install` is used to install (or replace) an executable in
`$V_TUT/bin`.

## Implementation

The following implementation stores fortune strings in memory,
choosing one randomly when `Get` is called.  A client can add more
fortunes via `Add`.

<!-- @serviceImpl @test @testui @completer -->
```
mkdir -p $V_TUT/src/fortune/service
 cat - <<EOF >$V_TUT/src/fortune/service/service.go
package service

import (
  "math/rand"
  "fortune/ifc"
  "sync"
  "v.io/v23/context"
  "v.io/v23/rpc"
)

type impl struct {
  wisdom []string      // All known fortunes.
  random *rand.Rand    // To pick a random index in 'wisdom'.
  mu     sync.RWMutex  // To safely enable concurrent use.
}

// Makes an implementation.
func Make() ifc.FortuneServerMethods {
  return &impl {
    wisdom: []string{
        "You will reach the heights of success.",
        "Conquer your fears or they will conquer you.",
        "Today is your lucky day!",
    },
    random: rand.New(rand.NewSource(99)),
  }
}

func (f *impl) Get(_ *context.T, _ rpc.ServerCall) (blah string, err error) {
  f.mu.RLock()
  defer f.mu.RUnlock()
  if len(f.wisdom) == 0 {
    return "[empty]", nil
  }
  return f.wisdom[f.random.Intn(len(f.wisdom))], nil
}

func (f *impl) Add(_ *context.T, _ rpc.ServerCall, blah string) error {
  f.mu.Lock()
  defer f.mu.Unlock()
  f.wisdom = append(f.wisdom, blah)
  return nil
}
EOF
go build fortune/service
```

# Build a server

Service in hand, we need a place to put it.

[Recall](#terminology) that a server associates an endpoint with a
dispatcher, and a dispatcher contains one or more services.  This
tutorial covers the simple case of a program with just _one_ server -
just one active port.  Further, the server has just _one_ service and
_one_ authorizer.

## Authorizer

Vanadium checks every request via a policy defined in an
implementation of `security.Authorizer`.

The tutorials will use several authorizer implementations.

At any given time, one implementation will be provided by a factory
function called `util.MakeAuthorizer` in a file called
`authorizer.go`.  To keep code simple (no branches, no signature
changes, etc.), switching to a new implementation means replacing the
file and recompiling.

The first version of `authorizer.go` invokes the default Vanadium
authorization policy (to be discussed [later][default-auth]):

<!-- @authorizer @test @testui @completer -->
```
mkdir -p $V_TUT/src/fortune/server/util
 cat - <<EOF >$V_TUT/src/fortune/server/util/authorizer.go
package util

import (
  "v.io/v23/security"
)

// Returns Vanadium's default authorizer.
func MakeAuthorizer() security.Authorizer {
  return security.DefaultAuthorizer()
}
EOF
go build fortune/server/util
```

## Dispatcher

Dispatcher implementations will be provided by a factory function
called `util.MakeDispatcher` in a file called `dispatcher.go`, an
arrangement allowing for low tech implementation swaps as described
above for the authorizer.

The version of `dispatcher.go` defined here results in the use of a
dispatcher built into Vanadium.  It's initialized with only _one_
service and uses reflection to invoke server methods.

<!-- @dispatcher @test @testui @completer -->
```
mkdir -p $V_TUT/src/fortune/server/util
 cat - <<EOF >$V_TUT/src/fortune/server/util/dispatcher.go
package util

import (
  "v.io/v23/rpc"
)

// Returns nil to trigger use of the default dispatcher.
func MakeDispatcher() (d rpc.Dispatcher) {
  return nil
}
EOF
go build fortune/server/util
```

## Initializer

The following utility package allows endpoints to be written to a flag
controlled file.

In this tutorial, rather than specify a port as was done in the
[hello world tutorial], we let the system pick a free one, and from it
generate an _endpoint specification_.

Every time the server starts, the endpoint address changes.  The
address is written to a file named via a flag.  A client must know
this address in order to connect to the server, so it reads it from
the file.

The [mount table tutorial] describes how a _mount table_ replaces this
file-based exchange with a service.


<!-- @intializer @test @testui @completer -->
```
mkdir -p $V_TUT/src/fortune/server/util
 cat - <<EOF >$V_TUT/src/fortune/server/util/initializer.go
package util

import (
  "flag"
  "fmt"
  "io/ioutil"
  "log"

  "v.io/v23/naming"
)

var (
  fileName = flag.String(
      "endpoint-file-name", "",
      "Write endpoint address to given file.")
)

func SaveEndpointToFile(e naming.Endpoint) {
  if *fileName == "" {
    return
  }
  contents := []byte(
      naming.JoinAddressName(e.String(), "") + "\n")
  if ioutil.WriteFile(*fileName, contents, 0644) != nil {
    log.Panic("Error writing ", *fileName)
  }
  fmt.Printf("Wrote endpoint name to %v.\n", *fileName)
}

EOF
go build fortune/server/util
```

## Installation

Construct a server executable by defining a `main` function.

The server's custom behavior will be encapsulated by the authorizer
and dispatcher defined above.

<!-- @server @test @testui @completer -->
```
mkdir -p $V_TUT/src/fortune/server
 cat - <<EOF >$V_TUT/src/fortune/server/main.go
package main

import (
  "flag"
  "fmt"
  "log"
  "fortune/ifc"
  "fortune/server/util"
  "fortune/service"

  "v.io/v23"
  "v.io/v23/rpc"
  "v.io/x/ref/lib/signals"
  _ "v.io/x/ref/runtime/factories/generic"
)

var (
  serviceName = flag.String(
      "service-name", "",
      "Name for service in default mount table.")
)

func main() {
  ctx, shutdown := v23.Init()
  defer shutdown()

  // Attach the 'fortune service' implementation
  // defined above to a queriable, textual description
  // of the implementation used for service discovery.
  fortune := ifc.FortuneServer(service.Make())

  // If the dispatcher isn't nil, it's presumed to have
  // obtained its authorizer from util.MakeAuthorizer().
  dispatcher := util.MakeDispatcher()

  // Start serving.
  var err error
  var server rpc.Server
  if dispatcher == nil {
    // Use the default dispatcher.
    _, server, err = v23.WithNewServer(
        ctx, *serviceName, fortune, util.MakeAuthorizer())
  } else {
    _, server, err = v23.WithNewDispatchingServer(
        ctx, *serviceName, dispatcher)
  }
  if err != nil {
    log.Panic("Error serving service: ", err)
  }
  endpoint := server.Status().Endpoints[0]
  util.SaveEndpointToFile(endpoint)
  fmt.Printf("Listening at: %v\n", endpoint)

  // Wait forever.
  <-signals.ShutdownOnSignals(ctx)
}
EOF
go install fortune/server
```

Successful installation places a new executable in the bin directory.

```
ls $V_TUT/bin
```
The server is now ready to go.  Next, make a client to work with it.

# Build a client

This client is short-lived; it starts, makes one call (`Get` or `Add`)
depending on a flag value, then exits.

<!-- @client @test @testui @completer -->
```
mkdir -p $V_TUT/src/fortune/client
 cat - <<EOF >$V_TUT/src/fortune/client/main.go
package main

import (
  "flag"
  "fmt"
  "time"

  "fortune/ifc"

  "v.io/v23"
  "v.io/v23/context"
  "v.io/x/lib/vlog"
  _ "v.io/x/ref/runtime/factories/generic"
)

var (
  server = flag.String(
      "server", "", "Name of the server to connect to")
  newFortune = flag.String(
      "add", "", "A new fortune to add to the server's set")
)

func main() {
  ctx, shutdown := v23.Init()
  defer shutdown()

  if *server == "" {
    vlog.Error("--server must be specified")
    return
  }
  f := ifc.FortuneClient(*server)
  ctx, cancel := context.WithTimeout(ctx, time.Minute)
  defer cancel()

  if *newFortune == "" { // --add flag not specified
    fortune, err := f.Get(ctx)
    if err != nil {
      vlog.Errorf("error getting fortune: %v", err)
      return
    }
    fmt.Println(fortune)
  } else {
    if err := f.Add(ctx, *newFortune); err != nil {
      vlog.Errorf("error adding fortune: %v", err)
      return
    }
  }
}
EOF
go install fortune/client
```

If that succeeds, a second binary will appear at

```
ls $V_TUT/bin
```

# Run the binaries

## First run

This first run will demonstrate that we don't yet have enough
things defined to make a successful request.

Start the server in the background:

```
kill_tut_process TUT_PID_SERVER
$V_TUT/bin/server --endpoint-file-name $V_TUT/server.txt &
TUT_PID_SERVER=$!
```

Before entering its event loop, the server writes the endpoint address
to `$V_TUT/server.txt`.  The client will read it shortly.


{{# helpers.warning }}
  # Warning - the next command demonstrates failure!

   The correct pieces are in place to attempt a request - but the next
   command shows that you've not yet established the conditions for
   authorization.

{{/ helpers.warning }}


Now run the client, feeding it the server's endpoint, and attempt to
get a fortune:

```
$V_TUT/bin/client --server `cat $V_TUT/server.txt`
```

The client will report an authorization error.

Let's change things to allow the call to succeed, then compare the two
situations.


## Second run

The simplest thing to do to allow a call to succeed under the [default
authorization policy][default-auth] is to run the client and server as
the same [principal] (think of this as an _identity_ for now).  This
makes the two processes indistinguishable from an authorization point
of view.

To do this, create a principal called `tutorial`.  The next command
writes credentials associated with the name `tutorial` into the
`$V_TUT/cred/basics` directory:

<!-- @principalTutorial @test @testui @completer -->
```
$V_BIN/principal create \
    --overwrite $V_TUT/cred/basics tutorial
```

The `--overwrite` flag is optional. Omit it if you want a warning if
you attempt to overwrite an existing principal.

Now kill the server and restart it, telling it to run with those
credentials:

<!-- @runServerAsPrincipal @test @testui @sleep -->
```
kill_tut_process TUT_PID_SERVER
$V_TUT/bin/server \
    --v23.credentials $V_TUT/cred/basics \
    --endpoint-file-name $V_TUT/server.txt &
TUT_PID_SERVER=$!
```

Run the client with the same credentials:

<!-- @runClientAsPrincipal @test @testui -->
```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/basics \
    --server `cat $V_TUT/server.txt`
```

This time, the `Get` RPC will succeed and a fortune will be displayed.

Likewise, `Add` works:

<!-- @clientGet @test @testui -->
```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/basics \
    --server `cat $V_TUT/server.txt` \
    --add 'Fortune favors the bold.'
```

Feel free to rerun this without the `--add` flag until you
randomly recover the new fortune.

## Authorization

Vanadium is secure by default. All communication channels are
encrypted and authenticated and all communication must satisfy an
authorization policy.

In the first run above, no credentials were specified, so the server's
Vanadium runtime assigned *randomly generated* credentials, including
a characteristic name generated from the environment, e.g.

> `{user}@{hostname}_{randomNumber}`

Likewise, the client ran with randomly generated credentials.  Random
credentials accompany requests, appear in logs, etc. and are
preferrable to building a policy around _missing_ credentials.

In the first run, the server didn't recognize the client's randomly
different credentials and thus didn't authorize it.

In the second run, the server effectively recognized the client as
itself, and authorized the call. The client and server ran with the
same credentials - they had the same principal and blessings.

In practice, it is absolutely *not normal* to use the same principal
for distinct processes. Usually the client and server processes would
be on different machines, so running them as the same principal would
imply copying private keys around the network, completely defeating
the concept of _private_.

## The vrpc client

Before continuing with more advanced tutorials, let's first introduce
a generally useful generic client called [vrpc].

It can talk to any Vanadium service.  Try it with yours:

<!-- @checkMethods @test @testui -->
```
$V_BIN/vrpc --v23.credentials $V_TUT/cred/basics \
    call `cat $V_TUT/server.txt` Get
$V_BIN/vrpc --v23.credentials $V_TUT/cred/basics \
    call `cat $V_TUT/server.txt` Add \"More cowbell.\"
```

It is also possible to inspect the services offered by your server:

<!-- @checkTheSignature @test @testui -->
```
$V_BIN/vrpc --v23.credentials $V_TUT/cred/basics \
  signature `cat $V_TUT/server.txt`
```

That output includes methods you wrote, plus built-in methods that
support Vanadium security and service discovery.

Report single methods like this:

<!-- @checkMethods @test @testui -->
```
$V_BIN/vrpc --v23.credentials $V_TUT/cred/basics \
  signature `cat $V_TUT/server.txt` Add
$V_BIN/vrpc --v23.credentials $V_TUT/cred/basics \
  signature `cat $V_TUT/server.txt` Get
```

## Clean up

<!-- @killServer @test @testui -->
```
kill_tut_process TUT_PID_SERVER
```


# Summary

* You created a server that hosted a Fortune service defined using VDL
  and made RPCs to it with a simple command line client.

* The [default security policy][default-auth] prevented your initial
  RPCs from working.

* You 'fixed' this by running the client and server as the _same_
  principal, allowing requests to succeed.

* You were introduced to the generic client `vrpc`.

[hello world tutorial]: /tutorials/hello-world.html
[install]: /installation/
[default-auth]: /tutorials/security/principals-and-blessings.html#default-authorization-policy
[vanadium-definition-language]: /glossary.html#vanadium-definition-language-vdl-
[blessing]: /glossary.html#blessing
[naming tutorials]: /tutorials/naming/
[mount table tutorial]: /tutorials/naming/mount-table.html
[suffix tutorial]: /tutorials/naming/suffix.html
[principal]: /glossary.html#principal
[classic-fortune]: http://en.wikipedia.org/wiki/Fortune_(Unix)
[concepts-security]: /concepts/security.html
[vrpc]: /glossary.html#vrpc
[cat command]: /tutorials/faq.html#where-is-the-source-code-
[Go]:  /tutorials/faq.html#do-i-need-to-know-go-
