= yaml =
title: Hello World
layout: tutorial
wherein: Vanadium says hello!
prerequisites: {completer: hello-world, scenario: a}
sort: 12
toc: true
= yaml =

# Introduction

Practically speaking, Vanadium is a set of Go and Java language
libraries (more languages coming), plus a few dozen services and
command line tools built on top of them.

The goal of this first tutorial is to get you to running code
as quickly as possible.  Subsequent tutorials will explain what's
happening here in more detail, and take you much further into
_security_ and _service discovery_.

When they do so, the tutorials create files in `$V_TUT` (likely
`$HOME/v23_tutorial`):
<!-- @displayVTut @test -->
```
echo $V_TUT
```

The initial tutorials use Go language examples, but
[you don't need to know Go][faq-go] to do them.

Since Vanadium is a distributed computing framework, its simplest demo
requires two programs - a _server_ and a _client_.

# Make a server

## The interface

The following command (read more about `cat` usage [here][cat
command]) creates a [Vanadium Definition
Language][vanadium-definition-language] file defining a _Hello_
service:

<!-- @defineService @test @completer -->
```
mkdir -p $V_TUT/src/hello/ifc
 cat - <<EOF >$V_TUT/src/hello/ifc/hello.vdl
package ifc

type Hello interface {
  // Returns a greeting.
  Get() (greeting string | error)
}
EOF
```

## Stub code

Use the `hello.vdl` file to generate Go code describing the hello
interface.  It will soon be linked into a client and server.

<!-- @compileInterface @test @completer -->
```
VDLROOT=$V23_RELEASE/src/v.io/v23/vdlroot \
    VDLPATH=$V_TUT/src \
    $V_BIN/vdl generate --lang go $V_TUT/src/hello/ifc
```

You can see the newly generated file here:
<!-- @compileInterface @test -->
```
ls $V_TUT/src/hello/ifc
```

## Implementation

The following implements the Hello interface:

<!-- @serviceImpl @test @completer -->
```
mkdir -p $V_TUT/src/hello/service
 cat - <<EOF >$V_TUT/src/hello/service/service.go
package service

import (
  "hello/ifc"
  "v.io/v23/context"
  "v.io/v23/rpc"
)

type impl struct {
}

func Make() ifc.HelloServerMethods {
  return &impl {}
}

func (f *impl) Get(_ *context.T, _ rpc.ServerCall) (
    greeting string, err error) {
  return "Hello World!", nil
}
EOF
```

## Build the server

Service in hand, we need an executable to serve it on the network.

<!-- @server @test @completer -->
```
mkdir -p $V_TUT/src/hello/server
 cat - <<EOF >$V_TUT/src/hello/server/main.go
package main

import (
  "log"
  "hello/ifc"
  "hello/service"
  "v.io/v23"
  "v.io/x/ref/lib/signals"
  _ "v.io/x/ref/runtime/factories/generic"
)

func main() {
  ctx, shutdown := v23.Init()
  defer shutdown()
  _, _, err := v23.WithNewServer(ctx, "", ifc.HelloServer(service.Make()), nil)
  if err != nil {
    log.Panic("Error listening: ", err)
  }
  <-signals.ShutdownOnSignals(ctx)  // Wait forever.
}
EOF
go install hello/server
```

Your server binary is here:
<!-- @checkTheBinary @test -->
```
ls $V_TUT/bin
```


# Make a client

This client is short-lived; it starts, makes a call, then exits.

<!-- @client @test @completer -->
```
mkdir -p $V_TUT/src/hello/client
 cat - <<EOF >$V_TUT/src/hello/client/main.go
package main

import (
  "flag"
  "fmt"
  "time"
  "hello/ifc"
  "v.io/v23"
  "v.io/v23/context"
  _ "v.io/x/ref/runtime/factories/generic"
)

var (
  server = flag.String(
      "server", "", "Name of the server to connect to")
)

func main() {
  ctx, shutdown := v23.Init()
  defer shutdown()
  f := ifc.HelloClient(*server)
  ctx, cancel := context.WithTimeout(ctx, time.Minute)
  defer cancel()
  hello, _ := f.Get(ctx)
  fmt.Println(hello)
}
EOF
go install hello/client
```

# Make a principal

All communication in Vanadium is authenticated, meaning both sides
must recognize each other's identity.  In this initial example we'll
cheat a bit - we'll define just one identity (called a __principal__),
then use it for _both_ the client and server.

Create a principal called `tutorial`:

<!-- @principalTutorial @test -->
```
$V_BIN/principal create \
    --overwrite $V_TUT/cred/basics tutorial
```

# Run your code

Start the server:

<!-- @runServerAsPrincipal @test @sleep -->
```
PORT_HELLO=23000  # Pick an unused port.
kill_tut_process TUT_PID_SERVER
$V_TUT/bin/server \
    --v23.credentials $V_TUT/cred/basics \
    --v23.tcp.address :$PORT_HELLO &
TUT_PID_SERVER=$!
```

Run the client to get a hello:

<!-- @runClientAsPrincipal @test -->
```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/basics \
    --server /localhost:$PORT_HELLO
```

That's it - you've built and run your first Vanadium apps.

# Clean up

<!-- @killServer @test -->
```
kill_tut_process TUT_PID_SERVER
```


# Summary

* You created a server hosting a Hello service on a fixed port defined
  using VDL, then used the service from a command line client.

* To be approved by Vanadium security, you used the same identity on
  both ends of the RPC, making the ends indistinguishable from each
  other, automatically authorizing their communication.

All of the above and more will be covered in detail in subsequent
tutorials.

[install]: /installation/
[default-auth]: /tutorials/security/principals-and-blessings.html#default-authorization-policy
[vanadium-definition-language]: /glossary.html#vanadium-definition-language-vdl-
[mount table tutorial]: /tutorials/naming/mount-table.html
[suffix tutorial]: /tutorials/naming/suffix.html
[principal]: /glossary.html#principal
[concepts-security]: /concepts/security.html
[vrpc]: /glossary.html#vrpc
[cat command]: /tutorials/faq.html#where-is-the-source-code-
[faq-go]: /tutorials/faq.html#do-i-need-to-know-go-
