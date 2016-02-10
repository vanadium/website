= yaml =
title: Globber
layout: tutorial
wherein: you use the Globber interface to create your own server namespace. This is an advanced tutorial.
prerequisites: {completer: globber, scenario: e}
sort: 35
toc: true
= yaml =

# Introduction

In the suffix [Part I] and [Part II] tutorials, we introduced the concept of
server namespace where multiple services on a single server can be accessed by
name and can be discovered with the _namespace glob_ command.

There are two variants of the `Globber` interface defined in [rpc/model.go]:
`AllGlobber`, and `ChildrenGlobber`. `AllGlobber` is the most flexible option,
but also the most difficult to implement correctly. It is used by specialized
applications like a mount table server. `ChildrenGlobber` provides most of the
same functionality, but is much easier to implement.

In this tutorial, you will learn how to implement complex namespaces
using the `ChildrenGlobber` interface.

# File server

A namespace is a tree structure similar to a file system. In the namespace,
the nodes are service objects and the edges are their names. In a file
system, the nodes are files or directories, and the edges are the file names
and directory names.

Let's create a server that mirrors a local directory tree in its namespace.

To do this, we'll use two new services and a custom dispatcher.

## Services

Let's create two services: one for files, one for directories.

### File service

<!-- @newFileService @test @completer -->
```
 mkdir -p $V_TUT/src/fileserver
 cat - <<EOF >$V_TUT/src/fileserver/file_service.go
package main

import (
  "errors"
  "v.io/v23/context"
  "v.io/v23/rpc"
)

type fileService struct {
  name string
}

func (s *fileService) GetContents(*context.T, rpc.ServerCall) ([]byte, error) {
  return nil, errors.New("method not implemented")
}

func (s *fileService) SetContents(*context.T, rpc.ServerCall, []byte) (error) {
  return errors.New("method not implemented")
}
EOF
```

__Code walk__

Since we're not going to send any calls to the file service in this example, we
leave it unimplemented.

The directory service is the interesting part.

### Directory service

<!-- @newDirService @test @completer -->
```
 cat - <<EOF >$V_TUT/src/fileserver/dir_service.go
package main

import (
  "os"
  "v.io/v23/context"
  "v.io/v23/glob"
  "v.io/v23/naming"
  "v.io/v23/rpc"
)

type dirService struct {
  name string
}

func (s *dirService) GlobChildren__(
    _ *context.T, call rpc.GlobChildrenServerCall, m *glob.Element) error {
  f, err := os.Open(s.name)
  if err != nil {
    return err
  }
  defer f.Close()
  fi, err := f.Readdir(0)
  if err != nil {
    return err
  }
  sender := call.SendStream()
  for _, file := range fi {
    name := file.Name()
    if m.Match(name) {
      if err := sender.Send(naming.GlobChildrenReplyName{name}); err != nil {
        return err
      }
    }
  }
  return nil
}
EOF
```

__Code walk__

`GlobChildren__` is a special method that is automatically detected by the
Vanadium infrastructure. It is called when the server receives a glob request,
e.g. from a client using `namespace glob` to inspect the server's namespace.

Service objects that can have children must implement `GlobChildren__` in
order to have their children appear in the server's namespace.

The _directory service_'s implementation iterates through the files in the
directory and sends the ones that match.

Since _files_ don't have children, the _file service_ doesn't need to implement
`GlobChildren__`.

Let's add a custom dispatcher that uses our two services.

## Dispatcher

<!-- @newDispatcher @test @completer -->
```
 cat - <<EOF >$V_TUT/src/fileserver/dispatcher.go
package main

import (
  "os"
  "path/filepath"
  "strings"
  "v.io/v23/context"
  "v.io/v23/security"
)

type myDispatcher struct {
  rootDir string
}

func (d *myDispatcher) Lookup(
    _ *context.T, suffix string) (interface{}, security.Authorizer, error) {

  relPath := filepath.Join(strings.Split(suffix, "/")...)
  path := filepath.Join(d.rootDir, relPath)
  fi, err := os.Stat(path)
  switch {
  case err != nil:
    return nil, nil, err
  case fi.IsDir():
    return &dirService{path}, nil, nil
  default:
    return &fileService{path}, nil, nil
  }
}
EOF
```

__Code walk__

This dispatcher maps the suffix to a file or directory on the local file system.
If it is a file, `Lookup` returns a `fileService` object. If it is a directory,
it returns a `dirService` object.

You might have noticed that we haven't used any [VDL]-generated stub code.
That's to keep this example as simple as possible. The main benefit of using
stub code in servers is [static type-checking], which means that the compiler
will enforce that all the method arguments and return values have the types
defined in the [VDL] file. Adding a [VDL] file is left as an exercise.

All we need now is the `main` function.

## main

<!-- @newMain @test @completer -->
```
 cat - <<EOF >$V_TUT/src/fileserver/main.go
package main

import (
  "flag"
  "log"
  "v.io/v23"
  "v.io/x/ref/lib/signals"
  _ "v.io/x/ref/runtime/factories/generic"
)

var (
  name = flag.String(
    "mount-name", "", "Name for service in default mount table.")
  root = flag.String(
    "root-dir", ".", "The root directory of the file server.")
)

func main() {
  ctx, shutdown := v23.Init()
  defer shutdown()

  _, _, err := v23.WithNewDispatchingServer(ctx, *name, &myDispatcher{*root})
  if err != nil {
    log.Panic("Failure creating server: ", err)
  }
  <-signals.ShutdownOnSignals(ctx)
}
EOF
go build fileserver
```

__Code walk__

The `main` function creates the vanadium server that serves our custom
dispatcher.

# Try it

Start a mount table.

<!-- @startMountTable @test @sleep -->
```
PORT_MT=23000  # Pick an unused port.
kill_tut_process TUT_PID_MT
$V_BIN/mounttabled \
    --v23.credentials $V_TUT/cred/basics \
    --v23.tcp.address :$PORT_MT &
TUT_PID_MT=$!
export V23_NAMESPACE=/localhost:$PORT_MT
```

Fire up the file server with its root directory set to "$V_TUT":

<!-- @buildServer @test @completer -->
```
go install fileserver
```

<!-- @runServer @test @sleep -->
```
kill_tut_process TUT_PID_SERVER
$V_TUT/bin/fileserver \
    --v23.credentials $V_TUT/cred/basics \
    --mount-name my-file-server \
    --root-dir "$V_TUT" &
TUT_PID_SERVER=$!
```

Let's take a look at the server's namespace.

<!-- @glob @test -->
```
$V_BIN/namespace \
    --v23.credentials $V_TUT/cred/basics \
    glob "my-file-server/..."
```

All the files under "$V_TUT" are in the server's namespace.

# Exercises

1. What would it take to modify the fortune server from [The suffix - Part I]
to organize the fortune services by category, e.g. romance, finance, sports,
etc.?

1. Finish the implementation of the file and directory services:
  * Write a service definition in [VDL].
  * Implement the missing methods.
  * Write a client for them.
  * Add your own Authorizer.

# Cleanup

<!-- @cleanup @test -->
```
kill_tut_process TUT_PID_SERVER
kill_tut_process TUT_PID_MT
unset V23_NAMESPACE
```

# Summary

  * Services that can have children in the namespace need to implement
    the `GlobChildren__` method.

[Part I]: /tutorials/naming/suffix-part1.html
[Part II]: /tutorials/naming/suffix-part2.html
[The suffix - Part I]: /tutorials/naming/suffix-part1.html
[VDL]: /glossary.html#vanadium-definition-language-vdl-
[rpc/model.go]: https://vanadium.googlesource.com/release.go.v23/+/master/rpc/model.go
[static type-checking]: https://en.wikipedia.org/wiki/Type_system#Type_checking
