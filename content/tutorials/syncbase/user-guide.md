= yaml =
title: Syncbase User Guide
layout: tutorial
wherein: you learn about Syncbase
toc: true
= yaml =

# Overview

Syncbase is a storage system for developers that makes it easy to synchronize
app data between devices. It works even when devices are not connected to the
Internet.

- Synchronization between one user's devices is trivial to configure; multiple
  users can synchronize specific data too
  - Low latency synchronization enables many apps to use storage for
    asynchronous communication
- Internet connection not required
  - Local storage still works when not connected to the internet
  - Synchronization protocol is peer-to-peer and works just as well over local
    WiFi or Bluetooth as the internet
- Conflict resolution system merges data when devices have been working offline
- Unified storage model handles both structured data and blobs
  - Structured databases are easy to use and queryable
  - Blob caching policies work well on resource-limited devices
- Powerful management tools
  - Leverages the Vanadium namespace and security system
  - Open source reference implementation of Syncbase for developers who want
    tight control over the data

The initial version of Syncbase is ready for testing and evaluation by early
adopters - it is suitable for prototyping, but not for production applications.

This document covers installation and basic usage. It should be enough for
developers to get started using Syncbase. For more details on the design, see
the [Syncbase Overview] document.

# Installation

Syncbase is a Go program that depends on Vanadium and several other libraries.
The following steps cover all of the prerequisites, and should work on both
Linux and OS X.

1. Follow the [installation instructions] to install prerequisites and fetch the
   Vanadium repositories, which include Syncbase as well as the Todos demo app.

   The instructions below assume you've set the `JIRI_ROOT` environment variable
   and have added `$JIRI_ROOT/devtools/bin` to your `PATH`:

        # Edit to taste.
        export JIRI_ROOT=${HOME}/vanadium
        export PATH=$PATH:$JIRI_ROOT/devtools/bin

   Recommended: Add the lines above to your `~/.bashrc` or similar.

2. Run the Syncbase tests.

        jiri go test v.io/v23/syncbase/...

3. Build the Syncbase server binary and other Vanadium tools.

        jiri go install v.io/...

<!-- TODO: On OS X, step (2) opens a bunch of warning popups about accepting
incoming connections. We should make all test servers listen on the loopback
address. -->

Note, the `jiri go` command simply augments the `GOPATH` environment variable
with the various paths to Vanadium Go code under the `JIRI_ROOT` directory, and
then runs the standard `go` tool.

You should now have the following binaries available, among others:

- `$JIRI_ROOT/release/go/bin/mounttabled`
- `$JIRI_ROOT/release/go/bin/syncbased`
- `$JIRI_ROOT/release/go/bin/vrpc`

<!-- TODO: Add instructions about how to run a cloud instance of Syncbase. -->

## Running the Todos Demo App

The [Todos demo app] is a web application that runs in Chrome. Before you can
run it, you must install the [Vanadium Chrome extension].

To run the app, follow the demo setup instructions here:
https://github.com/vanadium/todos/blob/master/demo.md

To get a fresh copy of the Vanadium source code and rebuild everything for the
demo, run these commands from the todos root dir:

    jiri update
    make clean

If you get certificate signature verification errors when running the webapp,
try uninstalling and reinstalling your [Vanadium Chrome extension].

# Basic Usage

In this section we demonstrate the basics of working with a local instance of
Syncbase: setting up an initial `<app>/<database>/<table>` hierarchy, reading
and writing data, and using batches.

Application developers are expected to use Syncbase through a client library.
Currently we provide client libraries for
[Go](https://vanadium.googlesource.com/roadmap.go.syncbase/+/master/v23/syncbase/model.go),
[JavaScript](https://vanadium.googlesource.com/roadmap.js.syncbase/+/master/src/syncbase.js),
[Java](#todo) (Android), and [Dart](#todo) (Mojo/Sky). In this guide, to keep
things simple and concise, we use the Go client library and ignore all errors
returned from Syncbase.

Let's create an app with a single NoSQL database, containing a single table. The
following code snippets assume we have a Syncbase instance serving at
`localhost:4002`.

    import "v.io/syncbase/v23/syncbase"
    ctx, shutdown := v23.Init() // initialize the Vanadium runtime
    defer shutdown()
    s := syncbase.NewService("/localhost:4002")
    a := s.App("myapp")
    a.Create(ctx, perms) // assumes "perms" is defined
    d := a.NoSQLDatabase("mydb", nil) // nil means no schema
    d.Create(ctx, perms)
    t := d.Table("mytable")
    t.Create(ctx, nil) // nil means copy perms from db

We've created the hierarchy `myapp/mydb/mytable`. Now, let's read and write some
key-value data to our table.

    t.Put(ctx, "foo", "mystr")
    t.Put(ctx, "bar", 600673)
    t.Put(ctx, "baz", mystruct) // assumes "mystruct" is defined
    var s1, s2 string
    var i1 int
    t.Get(ctx, "foo", &s1) // s1 will be "mystr"
    t.Get(ctx, "bar", &i1) // i1 will be 600673
    expectError(t.Get(ctx, "baz", &s2))  // s2 is the wrong type

Next, let's scan over a range of key-value records. Scan returns a stream object
that reads from a consistent snapshot taken at the time of the RPC.

    it := t.Scan(ctx, nosql.Range("a", "z")) // covers ["a", "z")
    it := t.Scan(ctx, nosql.Prefix("ba")) // covers keys with prefix "ba"
    for it.Advance() {
      var v *vdl.Value // can represent any type
      it.Value(&v)
      fmt.Println(it.Key(), v)
    }
    handleError(it.Err())

Syncbase also supports SQL-like queries to scan over rows that match some
predicate. For more information, see the [Queries](#queries) section of this
guide.

Finally, let's perform a set of operations in a batch. Batches follow ACID
semantics on the local Syncbase instance, and relaxed ACID semantics when used
with synchronization, as described in the [Syncbase Overview] document.

    // For a read-only batch (i.e. to read from a snapshot), we'd set
    // BatchOptions.ReadOnly to true.
    nosql.RunInBatch(ctx, d, wire.BatchOptions{},
                     func(bd nosql.BatchDatabase) error {
      bt = bd.Table("mytable")
      bt.Get(ctx, "bar", &i1) // i1 will be 600673
      bt.Put(ctx, "foo", fmt.Sprintf(i1))
      bt.Put(ctx, "bar", 2*i1)
    })

This batch writes the old value of "bar" to "foo" (as a string), then replaces
"bar" with twice its original value. `nosql.RunInBatch` is a helper function
that handles creating and committing the batch, as well as retrying the batch if
a concurrent batch preempted ours.

This concludes the "basic usage" section. For the complete Syncbase API, consult
the client library in your language of choice. For "real-world usage", see the
todos example app code.

# Data Modeling

Syncbase organizes data hierarchically: App > Database > Table > Row

The "App" layer of hierarchy allows for multiple apps to share the same Syncbase
instance, so that (for example) we can run a single Syncbase instance on a
mobile device to service all apps running on that device.

The Database is a set of NoSQL tables. It provides the scope for queries and
batches similar to many relational databases. We expect that most apps will have
a single database. It exists primarily because we expect to provide other types
of databases in the future (e.g. SQL, timeseries).

A Table is a lexicographically ordered set of rows with each row key mapping to
a single value. Values can be anything representable by [VOM] such as simple
types like string and int32 or complex, application-defined structs. We expect
that many developers will choose to use [VDL] to model their data, though they
are free to define structs in their native programming language. The values in a
single table can be heterogeneous, allowing for better spatial locality than
splitting the values into homogeneous tables.

We expect developers to give a common key prefix to related data. For example, a
TODO list might have a table like:

    <list uuid>                -> List
    <list uuid>/entries/<uuid> -> Entry
    <list uuid>/entries/<uuid> -> Entry

All entries in the list have a common prefix, making it easy to find all of the
entries in the list. Note the use of Universally Unique Identifiers (UUIDs). The
act of sharing and synchronizing this list with another user will cause this
list to be spliced into that user's database. By using UUIDs, we ensure that
this list will not collide with a list already in that database.

##  Access Control

Syncbase provides fine grained access control, using the [Vanadium security
model] for identification and authentication. Developers provide a key prefix to
control which rows are covered by a given access control list (ACL). If there
are multiple ACL prefixes for a row, the one with the longest prefix wins. This
behavior makes it easy to set an ACL on related data and have new data
automatically inherit the right ACL if possible.

In our example above, the list is fully collaborative, so the developer would
set a simple ACL like:

    <list uuid> -> {<owner>: Read, Write, Admin; <friends>: Read, Write}

All entries in the list would inherit this ACL. We expect that most apps will
use a single ACL for a group of related data, so we optimized for this case. To
hide an entry from the friends, the owner would create another ACL:

    <list uuid>/entries/<uuid> -> {<owner>: Read, Write, Admin}

The existence of this ACL is revealed to the lowest levels of Syncbase on the
friends' devices, but the content of the entry is not.

## Syncgroups

As you think about how to model the data for your application, it is important
to understand how to specify which data to sync between devices. A syncgroup
represents both what data should be synced and who to sync it with. The what is
specified with a set of key prefixes similar to access control. Therefore, it is
essential that related data have a common key prefix. See the section on
[Sync](#sync) below for more details. The who is specified by a syncgroup ACL
that determines the devices that are allowed to join the syncgroup. Typically
this is done by specifying the identities of the device owners (and not their
specific devices) to give each user the flexibility in selecting from which of
their device(s) to join the syncgroup and participate in the data
synchronization.

# Queries

The Syncbase query language, [syncQL], is very similar to SQL. SyncQL uses the
general structure of SQL's SELECT statement. It efficiently evaluates predicates
(the WHERE clause) inside the Syncbase process. It does not currently support
JOINs or indexes.

SyncQL uses the keywords k and v to represent the key and value for the row.
SyncQL can unpack structs to evaluate the fields within. In this example, the
structs in the Customer table have a field called "State". The query returns the
row key and complete value struct for each row where State is 'CA'.

    SELECT k, v FROM Customer WHERE v.State = 'CA'

Because the key has significant structure, it is useful to restrict the query to
a subset of the data. For example, to fetch all of the data for a customer with
UUID 12345 (i.e. all rows with the prefix 12345):

    SELECT v FROM Customer WHERE k LIKE "12345%"

See the syncQL specification for the complete language and more examples.

<!-- TODO: Add an example here that shows what Go code the developer would
write. -->

# Blobs

A blob is created within a database and identified by a unique BlobRef. The app
stores the BlobRef in a row in a NoSQL table (i.e. in the value structure of a
NoSQL entry). When the table is synchronized to another device, the BlobRef can
be used to fetch the blob and cache it in that device's local store. Blobs give
the app a mechanism for lazy-fetching of data compared to the eager syncing of
the NoSQL tables.

Because blobs are typically large, the APIs to put and get blobs use a streaming
interface.

    // Create a blob. Assumes an existing hierarchy myapp/mydb/mytable.
    s := syncbase.NewService("/localhost:4002")
    d := s.App("myapp").NoSQLDatabase("mydb", nil)
    b, err := d.CreateBlob(ctx)
    bw, err := b.Put(ctx)
    for moreData {
      err = bw.Send(dataByteArray)
    }
    err = bw.Close()
    err = b.Commit()
    blobRef := b.Ref()
    fmt.Printf("Blob written: BlobRef %s\n", blobRef)

The BlobRef is used to get the blob data. If the blob is not available locally,
Syncbase locates a device that has a copy of the blob, fetches it, caches it
locally, and streams it to the client.

    // Retrieve a blob. Assumes the same initialization above.
    b := d.Blob(blobRef)
    br, err := b.Get(ctx, 0) // Get the full blob, i.e. from offset 0.
    var data []byte
    for br.Advance() {
      data = append(data, br.Value()...)
    }
    err = br.Err()
    fmt.Printf("Blob read: BlobRef %s, len %d\n", blobRef, len(data))

# Sync

Syncbase provides peer-to-peer synchronization of data between a set of devices.
The cloud is just another peer, and is not required. Devices attempt to discover
one another by all means available, including the local network (over mDNS, aka
Bonjour) and a configurable set of name servers.

The fundamental unit of synchronization is a syncgroup. Syncgroups are tied to a
database and can span tables. A syncgroup specifies what data to sync (as a set
of table names and key prefixes) and who to sync it with (as an ACL specifying
who can join the syncgroup). Syncgroup data may overlap or be nested within the
data of other syncgroups. For example SG1 may specify prefixes "foo" and "bar"
with SG2 specifying prefixes "f" and/or "bar123".

To guarantee consistent access behavior across all devices within a syncgroup,
the app must create a prefix-ACL (aka data-ACL) for each syncgroup prefix before
it creates the syncgroup. Syncbase enforces this setup and synchronizes the
prefix-ACLs along with the data. This way on every device the same prefix-ACLs
are available and enforced for the synchronized data.

A syncgroup is identified by a globally unique name selected by the creator.
This name is given out-of-band to the other devices so they can join the
syncgroup. The syncgroup name is a Vanadium name that is used to make the RPC
calls to create or join the syngroup. Thus the syncgroup name must start with a
Vanadium-resolvable server name.

In many apps, you'll have one device create a syncgroup (e.g. a new todo list),
and other devices join that syncgroup. The following code creates a syncgroup
with table "mytable" and key prefix "foo".

<!-- TODO: This syncgroup setup code is somewhat obtuse. Hopefully we can
simplify the setup and improve the documentation. Various issues have been filed
to track this. -->

    // Assumes we've already created the hierarchy myapp/mydb/mytable.
    s := syncbase.NewService("/localhost:4002")
    d := s.App("myapp").NoSQLDatabase("mydb", nil)
    sg := d.Syncgroup("/localhost:4002/%%sync/myapp/mydb/mysg")
    sg.Create(ctx, wire.SyncgroupSpec{
      Description: "my syncgroup",
      Perms:       perms,
      Prefixes:    []wire.TableRow{{TableName: "mytable", Row: "foo"}},
      MountTables: []string{"/ns.dev.v.io:8101"},
    }, wire.SyncgroupMemberInfo{
      SyncPriority: 8
    })

The code below joins the syncgroup.

    sg.Join(ctx, wire.SyncgroupMemberInfo{
      SyncPriority: 8
    })

In some cases, an app won't know in advance whether it should create a syncgroup
or join an existing syncgroup. For example, this can happen when an app uses a
syncgroup to sync a user's data across their devices; in this case, the app
won't know in advance whether it has already been installed on some other device
belonging to the user. This implies that the syncgroup name must be known in
advance by all instances of the app. In this case, the recommended approach is
to try to join that syncgroup. If the join fails with an error indicating that
the syncgroup does not exist (ErrNoExist), as opposed to a permission denial or
a network communication error, then create the syncgroup. This could still lead
to multiple concurrent creations of the syncgroup. In the future we plan to
provide a mechanism for apps to merge such disconnected syncgroups when there is
no ambiguity as to whether they really ought to be the same syncgroup.

## Conflict Resolution

Syncbase was designed to allow for predefined conflict resolution policies such
as last-write-wins as well as custom, app-driven conflict resolution. The
Syncbase implementation does not yet expose hooks for custom resolvers;
last-write-wins is the only resolver currently available.

*TODO: Expand this section once we finish adding support for custom conflict
resolvers, additional types of predefined resolvers, CRDTs, etc.*

*TODO: Maybe add some info about schemas here.*

## Interaction with ACLs

*TODO: Fill this out.*

# Frequently Asked Questions

*TODO: Grow this section as questions arise.*

[Syncbase Overview]: /concepts/syncbase-overview.html
[installation instructions]: /installation/
[syncQL]: /tutorials/syncbase/syncql-tutorial.html
[VOM]: /concepts/rpc.html#vom
[VDL]: /concepts/rpc.html#vdl
[Vanadium security model]: /concepts/security.html
[todos demo app]: https://github.com/vanadium/todos
[Vanadium Chrome extension]: /tools/vanadium-chrome-extension.html
