= yaml =
title: The Mount Table
layout: tutorial
wherein: you use the basic tools of service discovery.
prerequisites: {scenario: b}
sort: 31
toc: true
= yaml =

# Introduction

This tutorial focusses on using a mount table with the _fortune_
server and client programs you made in the [basics tutorial], and just
re-made with the prerequisites script above.

## Credentials

To keep security simple initially, all processes here will
[use the same credentials].  Further, credentials will be specified
using this environment variable:

<!-- @setCredentials @test -->
```
export V23_CREDENTIALS=$V_TUT/cred/basics
```

Vanadium programs consult this environment variable when the
credentials aren't specified by using the `--v23.credentials` flag,
or by using a [security agent][agent tutorial].

# Start a table

When you ran the fortune server in the [basics tutorial], you told it
to write its network [endpoint] to a file, then you told the client to
read that file so it would know where to find the server.

Let's do that again, but this time instead of using a file to hold the
endpoint, we'll use a server.

The server is called a _mount table_, and its executable has the name
`mounttabled`:

<!-- @startMountTable @test @sleep -->
```
PORT_MT=23000  # Pick an unused port.
kill_tut_process TUT_PID_MT
$V_BIN/mounttabled --v23.tcp.address :$PORT_MT &
TUT_PID_MT=$!
```

A mount table happens to be a Vanadium service.  This means the [vrpc]
program can report its [VDL interface][mounttable interface]:

<!-- @queryMountTable @test -->
```
$V_BIN/vrpc signature /localhost:$PORT_MT
```

It also means that the mount table has a [principal] - it must run
with credentials.  Since the `--v23.credentials` flag wasn't
specified at startup, the Vanadium runtime consulted the environment
variable `V23_CREDENTIALS` (set above) to get the credentials.

Had credentials been left unspecified, randomly generated credentials
would have been used, and the problems reviewed at the
[end of the basics tutorial][random credentials] would happen below
when processes start talking to each other.  Mount table security will
be discussed in later tutorial.

# The namespace client

The table is up, but empty.

Start the existing fortune server binary, so we have a service to put
in the table:

<!-- @startFortune @test @sleep -->
```
kill_tut_process TUT_PID_S1
$V_TUT/bin/server --endpoint-file-name $V_TUT/s1.txt &
TUT_PID_S1=$!
```

## Mounting


`namespace` is a command line client dedicated to manipulating mount
tables.  The following mounts the server at the name `fortuneAlpha`.

<!-- @mountFortune @test -->
```
$V_BIN/namespace \
    --v23.namespace.root /localhost:$PORT_MT \
    mount fortuneAlpha `cat $V_TUT/s1.txt` 100m
```

The flag `--v23.namespace.root` specifies which __mount table__ to
use.  The flag is available in all Vanadium programs.

In Vanadium, services live in hierachical trees called the
__namespaces__.  The _root_ node of a tree is a mount table, hence the
flag name.  Other nodes are either services (leaves) or other mount
tables.

## Globbing

_To [glob]_ is to use a character pattern to select strings from a set.

The command `namespace glob *` reports the names of _all_ known
names:

<!-- @queryMountTable @test -->
```
$V_BIN/namespace \
    --v23.namespace.root /localhost:$PORT_MT \
    glob -l '*'
```

There's just one name: `fortuneAlpha`.  Use of the flag `-l`
triggers additional output; you see the name's [endpoint],
and you see it will expire (will be dropped from the table) in
about one hundred minutes.  That's what the `100m` meant in the
`mount` command above.

## Resolution

When a name is known, and you just want to resolve it to an
[endpoint], use `namespace resolve {name}`:

<!-- @resolveFortune @test -->
```
$V_BIN/namespace \
    --v23.namespace.root /localhost:$PORT_MT \
    resolve fortuneAlpha
```

The output should match the endpoint recorded in `$V_TUT/s1.txt`:

<!-- @lookAtEndpoint @test -->
```
cat $V_TUT/s1.txt
```

# Name usage

Recapping, here's how you connected the fortune client to the fortune
server using a full service endpoint name in the [basics tutorial]:

<!-- @reviewFortune @test -->
```
$V_TUT/bin/client --server `cat $V_TUT/s1.txt`
```

Now you can use the name `fortuneAlpha` instead:

<!-- @fortuneWithTable @test -->
```
$V_TUT/bin/client \
    --v23.namespace.root /localhost:$PORT_MT \
    --server fortuneAlpha
```

The `client` program didn't need to be recompiled to allow this new
usage because Vanadium code in the client interprets the value
of the `--server` flag.

In the first command, `--server`'s value was something like
`/@3@tcp@127.0.0.1:...`.  The leading `/` caused it to be interpreted
directly as an [endpoint] rather than as a service name to be used as
a lookup key.  That means communication attempts begin immediately,
and if the string doesn't refer to a live service, you won't know it
until the attempts timeout.

In the second command, `--server`'s value was just `fortuneAlpha`.
Strings that don't start with `/` are treated as service names needing
a lookup.  If a lookup fails, the client will know it immediately, and
may retry depending on various configurations.

## The namespace variable

This tutorial uses only one mount table, and it's repetitive to
constantly specify the `--v23.namespace.root` flag with the same
value.

Ommiting the flag will trigger use the following shell variable:

<!-- @setNamespace @test -->
```
export V23_NAMESPACE=/localhost:$PORT_MT
```

Now a fortune retrieval is as simple as:

<!-- @fortuneWithTableAgain @test -->
```
$V_TUT/bin/client --server fortuneAlpha
```

## Flags vs. variables

In Vanadium, flag values, when specified, always trump the values of
corresponding shell variables.  So `--v23.namespace.root` trumps
`$V23_NAMESPACE`, and `--v23.credentials` trumps `$V23_CREDENTIALS`.

Shell variable values, in turn, trump default behavior.

The default behavior for unspecified namespace is to use a public
mount table maintained by the v23 team.  Circa April 2015 the service
runs at `ns.dev.v.io:8101`.  The port serves Vanadium protocol, not
HTTP.

The default behavior for unspecified credentials is to generate
[random credentials].

## Many names, one endpoint

A single service instance can have multiple names.  Mount the same
service again, with the name `fortuneBeta`, and a brief time to live:

<!-- @mountFortune @test -->
```
$V_BIN/namespace mount fortuneBeta `cat $V_TUT/s1.txt` 5m
```

Do the `glob` again:

<!-- @doTheGlob @test -->
```
$V_BIN/namespace glob -l '*'
```

You'll see two names, with the same endpoint, but with _different_
expiration times.  Later you'll find the names can have different
access control lists as well.

Confirm that the second name works:

<!-- @fortuneViaOtherName @test -->
```
$V_TUT/bin/client --server fortuneBeta
```

## Many endpoints, one name

Start a __second instance__ of the fortune server:

<!-- @startAnotherFortune @test @sleep -->
```
kill_tut_process TUT_PID_S2
$V_TUT/bin/server --endpoint-file-name $V_TUT/s2.txt &
TUT_PID_S2=$!
```

Mount it on the (original) name `fortuneAlpha`:

<!-- @mountFortuneAgain @test -->
```
$V_BIN/namespace mount fortuneAlpha `cat $V_TUT/s2.txt` 100m
```

List the names again:

<!-- @doTheGlob @test -->
```
$V_BIN/namespace glob -l '*'
```

Now the name `fortuneAlpha` reports two endpoints, with distinct
expiration times.

This is a means to implement redundancy, load sharing, etc.  The mount
table will resolve specific requests to one endpoint, but multiple
endpoints let it assign a server using simple rotation, or by using
load, response times, etc.

Confirm that `fortuneAlpha` still works (with two endpoints):

<!-- @fortuneViaOriginalName @test -->
```
$V_TUT/bin/client --server fortuneAlpha
```

Now kill the original server:

<!-- @killTutS1 @test -->
```
kill_tut_process TUT_PID_S1
```

And retry the request:

<!-- @fortuneFromS2 @test -->
```
$V_TUT/bin/client --server fortuneAlpha
```

You should still get a fortune, but this time it can only come from
the second server instance.

The mount table will still report the dangling endpoint until it
expires, as it might come back to life.

# Unmounting

Unmounting works as you might expect:

<!-- @unmountFortune @test -->
```
$V_BIN/namespace unmount fortuneAlpha `cat $V_TUT/s1.txt`
$V_BIN/namespace unmount fortuneBeta `cat $V_TUT/s1.txt`
```

That leaves only server 2 in the table (with the name `fortuneAlpha`):

<!-- @globAfterUnmountFortune @test -->
```
$V_BIN/namespace glob -l '*'
```

The reported endpoint should match the stored endpoint of server 2:

<!-- @catS2Name @test -->
```
cat $V_TUT/s2.txt
```

Unmount it as well:
<!-- @globAfterUnmountFortune @test -->
```
$V_BIN/namespace unmount fortuneAlpha `cat $V_TUT/s2.txt`
```

{{# helpers.warning }}
## Optionally observe failure

Optionally, confirm that client use of the unmounted name `fortuneAlpha` fails.
Feel free to interrupt before the retry attempts exhaust themselves.

```
$V_TUT/bin/client --server fortuneAlpha
```
{{/ helpers.warning }}

{{# helpers.hidden }}

Must resolve https://github.com/veyron/release-issues/issues/1871
before exposing this part.

# Cloud service

The Vanadium team plans to maintain several mount tables,
e.g. a public one at `ns.dev.v.io:8101`.  Try mounting your
service in it:

<!-- @cloudCheck -->
```
V23_NAMESPACE=/ns.dev.v.io:8101
sName=`hostname`Fortune
$V_BIN/namespace mount $sName `cat $V_TUT/s2.txt` 3m
$V_TUT/bin/client --server $sName
$V_BIN/namespace unmount $sName `cat $V_TUT/s2.txt`
unset sName
```
{{/ helpers.hidden }}

# Cleanup

<!-- @cleanup @test -->
```
kill_tut_process TUT_PID_S2
kill_tut_process TUT_PID_MT
unset V23_CREDENTIALS
unset V23_NAMESPACE
```

# Summary

* A service called `mounttabled` is a Vanadium service that helps
  Vanadium services find each other.

* The command-line client `namespace` performs
  general operations on an instance of `mounttabled`.

* The shell variables `$V23_CREDENTIALS` and `$V23_NAMESPACE`
  can be used instead of flags to configure a Vanadium program.

[naming concepts document]: /concepts/naming.html
[basics tutorial]: /tutorials/basics.html
[random credentials]: /tutorials/basics.html#authorization
[principal]: /glossary.html#principal
[endpoint]: /glossary.html#endpoint
[VDL]: /glossary.html#vanadium-definition-language-vdl-
[vrpc]: /tutorials/basics.html#the-vrpc-client
[agent tutorial]: /tutorials/security/agent.html
[namespace tutorial]: /tutorials/naming/namespace.html
[mounttable interface]: https://vanadium.googlesource.com/release.go.v23/+/master/services/mounttable/service.vdl
[use the same credentials]: /tutorials/basics.html#authorization
[glob]: http://en.wikipedia.org/wiki/Glob_%28programming%29
