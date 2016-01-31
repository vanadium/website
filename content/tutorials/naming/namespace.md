= yaml =
title: Namespaces
layout: tutorial
wherein: you manipulate multiple mount tables to create a rich namespace.
prerequisites: {scenario: b}
sort: 32
toc: true
= yaml =

# Introduction

As done in the mount table tutorial, this tutorial will use just
[one set of credentials][credentials] for all processes:

<!-- @setCredentials @test -->
```
export V23_CREDENTIALS=$V_TUT/cred/basics
```

This tutorial will use three distinct mount table servers, named
`HOME`, `METERS` and `UTILITY`.  These names are in uppercase to
distinguish them from service names used in table entries, where we'll
stick with a lowercase convention.

Start `HOME` first:

<!-- @startTableHome @test @sleep -->
```
PORT_MT_HOME=23000  # Pick an unused port.
kill_tut_process TUT_PID_MT_HOME
$V_BIN/mounttabled --v23.tcp.address :$PORT_MT_HOME &
TUT_PID_MT_HOME=$!
```

Start a fortune server:

<!-- @startFortune @test @sleep -->
```
kill_tut_process TUT_PID_SERVER
$V_TUT/bin/server \
    --endpoint-file-name $V_TUT/server.txt &
TUT_PID_SERVER=$!
```

Add the fortune server to table `HOME`, and for reasons explained
below, call it `television`:

<!-- @mountFortune @test -->
```
$V_BIN/namespace \
    --v23.namespace.root /:$PORT_MT_HOME \
    mount television `cat $V_TUT/server.txt` 2h
```

# Table in a table

Like any Vanadium service, a mount table can be mounted in a mount
table.

Start table `METERS`:

<!-- @startTableMeters @test @sleep -->
```
PORT_MT_METERS=$(( $PORT_MT_HOME + 1 ))
kill_tut_process TUT_PID_MT_METERS
$V_BIN/mounttabled --v23.tcp.address :$PORT_MT_METERS &
TUT_PID_MT_METERS=$!
```

Mount it in table `HOME` at the name `meters`:

<!-- @tableInATable @test -->
```
$V_BIN/mounttable \
    --v23.namespace.root /:$PORT_MT_HOME \
    mount meters /:$PORT_MT_METERS 2h M
```

The trailing `M` sets a bit in the mount table noting that this
particular service happens to be a table.

{{# helpers.info }}

`mounttable` and `namespace` are distinct tools with _almost_ the same
abilities (see their help).  The `mounttable` tool doesn't
do name resolution and speaks directly to a single mount table.
The `namespace` tool behaves more like a normal Vanadium client.
{{/ helpers.info }}

The `HOME` table now has two entries, `meters` and `television`:

<!-- @firstGlobOfHome @test -->
```
$V_BIN/namespace \
    --v23.namespace.root /:$PORT_MT_HOME \
    glob '*'
```

That exercises the basic commands needed to manipulate namespace.

# Namespace construction

The `METERS` table is empty right now, so lets add two services to it.
To save time, reuse the fortune service that's already running.  New,
distinct instances wouldn't make any difference to this example.

Mount the services as `gas` and `electric` in the `METERS` table:

<!-- @mountGas @test -->
```
$V_BIN/namespace \
    --v23.namespace.root /:$PORT_MT_METERS \
    mount gas `cat $V_TUT/server.txt` 2h
```

<!-- @mountElectricFortune @test -->
```
$V_BIN/namespace \
    --v23.namespace.root /:$PORT_MT_METERS \
    mount electric `cat $V_TUT/server.txt` 2h
```

The namespace you've built is represented here:

![The HOME namespace](/images/tut/namespace-home-simple.svg)

Query the `HOME` table again, but this time
stead of `*`, try `...` as an argument to `namespace glob`:

<!-- @queryTableInATable @test -->
```
$V_BIN/namespace \
    --v23.namespace.root /:$PORT_MT_HOME \
    glob '...'
```

This shows `television`, `meters`, `meters/gas` and `meters/electric`
along with endpoints.

This means services available as root names to clients of `METERS` are
now also available to clients of `HOME`.  For example, you can read
the `gas` meter via the `HOME` table:

<!-- @fortuneNestedInTable @test -->
```
$V_TUT/bin/client \
    --v23.namespace.root /:$PORT_MT_HOME \
    --server meters/gas
```

Your television could display data from `meters/gas` or `meters/electric`.
Likewise, other services like `mediaServer` and `doorLock` can be
mounted in your `HOME`, making them discoverable by the `television`.
The `HOME` table is your home's __namespace root__.

# Single table namespace

The name to service mapping supported by the above arrangement can
also be done with a single mount table, like this:

![Single table namespace](/images/tut/namespace-home-direct.svg)

That is, we could have omitted the `METERS` table entirely, and
mounted the service in `HOME` at the name `meters/gas` with this
alternative to the command used above (__don't do this now!__):

<!-- @mountElectricFortune @test -->
```
$V_BIN/namespace \
    --v23.namespace.root /:$PORT_MT_HOME \
    mount meters/gas `cat $V_TUT/server.txt` 2h
```

The trick is simply to use the special delimiter `/` directly in a
name.

One might do this for the same reason one would group files in
particular folders on a computer, but it means giving up the ability
to export parts of your namespace to others, as described in the next
section.

# Mixing remote and local

With the proper blessings you could safely mount your `METERS` table
in a city-wide utility company table under your account number
`12345`.

Let's start another table `UTILITY`:

<!-- @startTableUtility @test @sleep -->
```
PORT_MT_UTILITY=$(( $PORT_MT_METERS + 1 ))
kill_tut_process TUT_PID_MT_UTILITY
$V_BIN/mounttabled --v23.tcp.address :$PORT_MT_UTILITY &
TUT_PID_MT_UTILITY=$!
```

Now mount your `METERS` in it, at a particular account number
`12345`:

<!-- @mountMetersInUtility @test -->
```
$V_BIN/mounttable \
    --v23.namespace.root /:$PORT_MT_UTILITY \
    mount 12345 /:$PORT_MT_METERS 5h M
```

The utility company can see the table you call `METERS` as an account
number `12345` - and the utility can see its children `gas` and
`electric`.

The utility company has no pointer to your `mediaServer` or other home
services, by virtue of the meter table's independent existence.

You likely _don't_ want to mount all your local services in a
neighborhood, city or national table (Vanadium security measures would
prevent this anyway to avoid the equivalent of DNS poisoning).

But you _do_ want to access global services locally, so you (or some
software under your control) would mount appropriate public tables
locally.  That way your `television` can discover
`GOOGLE/PLAY/MOVIES/starwars` (after `GOOGLE` is mounted locally).

As an example of this, mount the `UTILITIES` table in `HOME`:

<!-- @mountUtilitiesInHome @test -->
```
$V_BIN/mounttable \
    --v23.namespace.root /:$PORT_MT_HOME \
    mount cityUtilities /:$PORT_MT_UTILITY 5h M
```

![The HOME namespace](/images/tut/namespace-home-extended.svg)

Now, your television could display your gas usage by hitting the name
`METERS/gas` (done above) or by hitting the name
`cityUtilities/12345/gas`:

<!-- @readGas @test -->
```
$V_TUT/bin/client \
    --v23.namespace.root /:$PORT_MT_HOME \
    --server cityUtilities/12345/gas
```

# Cycles OK

The fact that your gas meter is available via two distinct paths
raises the question of cycles.  Cycles aren't prohibited.

To see what happens, mount the `UTILITY` table in the `METERS` table
with a short name `x`:

<!-- @mountUtilityInMeters @test -->
```
$V_BIN/mounttable \
    --v23.namespace.root /:$PORT_MT_METERS \
    mount x /:$PORT_MT_UTILITY 5h M
```

Now read your gas meter via a name with cycles:

<!-- @longName @test -->
```
$V_TUT/bin/client \
    --v23.namespace.root /:$PORT_MT_HOME \
    --server meters/x/12345/x/12345/x/12345/x/12345/gas
```

Infinite cycles in namespace resolution are prevented by counting steps
(there's an upper limit on the `/` count in any name).

Use `namespace resolve` to see that you're accessing the same service:

<!-- @moreResolving @test -->
```
name1=$($V_BIN/namespace \
    --v23.namespace.root /:$PORT_MT_HOME \
    resolve meters/x/12345/x/12345/x/12345/x/12345/gas)
name2=$($V_BIN/namespace \
    --v23.namespace.root /:$PORT_MT_METERS \
    resolve gas)
echo "These should match:"
echo -e "$name1\n$name2"
```

Of course `television` will also resolve to this name because we're
reusing the same service.  Feel free to go back and start fresh server
instances for `gas` and `electric` and do the same commands to assure
yourself that `gas` doesn't get confused with `electric` or
`television`.

Take a look all at the path expansions using `namespace glob ...`:

<!-- @queryTableInATable @test -->
```
$V_BIN/namespace \
    --v23.namespace.root /:$PORT_MT_HOME \
    glob '...'
```

# Cleanup

<!-- @cleanup @test -->
```
kill_tut_process TUT_PID_SERVER
kill_tut_process TUT_PID_MT_HOME
kill_tut_process TUT_PID_MT_METERS
kill_tut_process TUT_PID_MT_UTILITY
unset V23_CREDENTIALS
```

# Summary

* The command-line client `mounttable` supplements `namespace` to
  perform general operations on an instance of `mounttabled`.

* Mount tables can be mounted on each other to create isolated
  namespaces.

* Mounting a table in another table can be viewed as exporting a
  subset of a namespace.

* The `namespace glob ...` command shows service path expansions.

* Namespace cycles are allowed and controlled by counting.

[naming concepts document]: /concepts/naming.html
[basics tutorial]: /tutorials/basics.html
[credentials]: /tutorials/naming/mount-table.html#credentials
[endpoint]: /glossary.html#endpoint
[VDL]: /glossary.html#vanadium-definition-language-vdl-
[vrpc]: /tutorials/basics.html#the-vrpc-client
[security tutorials]: /tutorials/security/
[agent tutorial]: /tutorials/security/agent.html
[mounttable interface]: https://vanadium.googlesource.com/release.go.v23/+/master/services/mounttable/service.vdl
