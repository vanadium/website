= yaml =
title: Syncing
layout: tutorial
wherein: we distribute the fortune teller service state across multiple devices using Syncbase.
prerequisites: {completer: syncbase-sync, scenario: f}
sort: 14
toc: true
= yaml =

# Introduction

In this tutorial, we will extend the Syncbase [local persistence tutorial] so
that multiple fortune teller services can _exchange_ data.

Syncbase uses collections as the unit of synchronization. Devices join groups
called _syncgroups_, and each syncgroup manages one or more collections and
ensures that each device in the syncgroup receives updates to its collections.
In this tutorial we will add the fortune collection from the [local persistence
tutorial] to a new syncgroup, and then add multiple fortune services to the same
syncgroup in order to exchange data between them.

# Modifying the Service

First, we need to modify the service to join a syncgroup, and make small changes to the
`Add` and `Get` RPCs.

<!-- @defineService @test @completer -->
```
mkdir -p $V_TUT/src/fortune/service
 cat - <<EOF >$V_TUT/src/fortune/service/service.go
{{# helpers.codedim}}
package service

import (
  "fortune/ifc"
  "math/rand"
  "strconv"
  "strings"
  "sync"

  "v.io/v23/context"
  "v.io/v23/rpc"
  "v.io/v23/security"
  "v.io/v23/security/access"
  wire "v.io/v23/services/syncbase"
  "v.io/v23/syncbase"
)

// Constant names of different Syncbase entities.
const (
  fortuneDatabaseName   = "fortuneDb"
  fortuneCollectionName = "fortuneCollection"
{{/ helpers.codedim}}
  fortuneSyncgroupName  = "fortuneSyncgroup"
{{# helpers.codedim}}

  // A special key that specifies the number of fortunes.
  numFortunesKey = "numFortunes"
)

type impl struct {
  random *rand.Rand   // To pick a random fortune
  mu     sync.RWMutex // To safely enable concurrent use.

  syncbaseName       string // The Syncbase endpoint
  remoteSyncbaseName string // A remote endpoint to connect to

  sbs syncbase.Service    // Handle to the Syncbase service
  d   syncbase.Database   // Handle to the fortunes database
  c   syncbase.Collection // Handle to the fortunes collection
}

// Makes an implementation.
func Make(ctx *context.T, syncbaseName, remoteSyncbaseName string) ifc.FortuneServerMethods {
  impl := &impl{
    random:             rand.New(rand.NewSource(99)),
    syncbaseName:       syncbaseName,
{{/ helpers.codedim}}
    remoteSyncbaseName: remoteSyncbaseName,
{{# helpers.codedim}}
  }

  if err := impl.initSyncbase(ctx); err != nil {
    panic(err)
  }
  return impl
}

// Initialize Syncbase by establishing a new service and creating a new database
// and a new collection.
func (f *impl) initSyncbase(ctx *context.T) error {

  // Create a new service and get its database.
  sbs := syncbase.NewService(f.syncbaseName)
  d := sbs.Database(ctx, fortuneDatabaseName, nil)
  if err := d.Create(ctx, nil); err != nil {
    return err
  }

  // Create the collection where we will store fortunes.
  c := d.Collection(ctx, fortuneCollectionName)
  if err := c.Create(ctx, nil); err != nil {
    return err
  }

{{/ helpers.codedim}}
  // Join a syncgroup if there is someone to connect to, otherwise create one.
  sg := d.Syncgroup(ctx, fortuneSyncgroupName)
  sgPerms := access.Permissions{}
  sgPerms.Add(security.BlessingPattern(sg.Id().Blessing),
    access.TagStrings(wire.AllSyncgroupTags...)...)

  sgSpec := wire.SyncgroupSpec{
    Description: "FortuneSyncgroup",
    Perms:       sgPerms,
    Collections: []wire.Id{c.Id()},
  }
  sgInfo := wire.SyncgroupMemberInfo{SyncPriority: 10}

  if f.remoteSyncbaseName != "" {
    if _, err := sg.Join(ctx, f.remoteSyncbaseName, nil, sgInfo); err != nil {
      return err
    }
  } else {
    if err := sg.Create(ctx, sgSpec, sgInfo); err != nil {
      return err
    }
  }
{{# helpers.codedim}}

  f.sbs = sbs
  f.d = d
  f.c = c
  return nil
}

// Get RPC implementation. Returns a fortune retrieved from Syncbase.
func (f *impl) Get(ctx *context.T, _ rpc.ServerCall) (string, error) {
  f.mu.RLock()
  defer f.mu.RUnlock()

{{/ helpers.codedim}}
  counts := make([]int, 0)
  devices := make([]string, 0)
  it := f.c.Scan(ctx, syncbase.Prefix(numFortunesKey))
  for it.Advance() {
    var numFortunes int
    dev := strings.TrimPrefix(it.Key(), numFortunesKey)
    if err := it.Value(&numFortunes); err != nil {
      return "[error]", err
    }

    if numFortunes > 0 {
      counts = append(counts, numFortunes)
      devices = append(devices, dev)
    }
  }

  if len(counts) == 0 {
    return "[empty]", nil
  }

  index := f.random.Intn(len(counts))
  count := counts[index]
  dev := devices[index]

  // Get a random number in the range [0, numKeys) and convert it to a string;
  // this acts as the key in the fortunes collection.
  key := strconv.Itoa(f.random.Intn(count)) + dev
{{# helpers.codedim}}

  var value string
  if err := f.c.Get(ctx, key, &value); err == nil {
    return value, nil
  } else {
    return "[error]", err
  }
}

// Add RPC implementation. Adds a new fortune by persisting it to Syncbase.
func (f *impl) Add(ctx *context.T, _ rpc.ServerCall, fortune string) error {
  f.mu.Lock()
  defer f.mu.Unlock()
{{/ helpers.codedim}}

  var numKeys int
  if err := f.c.Get(ctx, numFortunesKey+f.syncbaseName, &numKeys); err != nil {
    numKeys = 0
  }

  // Put the fortune into Syncbase.
  key := strconv.Itoa(numKeys)
  if err := f.c.Put(ctx, key+f.syncbaseName, &fortune); err != nil {
    return err
  }

  // Update the number of keys.
  return f.c.Put(ctx, numFortunesKey+f.syncbaseName, numKeys+1)

{{# helpers.codedim}}
}
{{/ helpers.codedim}}


EOF
```

__Code Walk__<br>

Our `Make` function now takes one new argument: a `remoteSyncbaseName`. This
name points to another existing Syncbase instance that this service will use to
join the syncgroup. If the name is an empty string, then the service is
responsible for creating the syncgroup (and other services will use the service
as their remote).

The new code in the `initSyncbase` function sets up permissions on the new
syncgroup, adds the fortune collection to it, and then tries to join a syncgroup
or creates one if no remote exists.

We have changed all our `Get` and `Put` calls to Syncbase by appending the
(unique) Syncbase name to each key. This is because by default, Syncbase uses a
_last write wins_ policy to resolve conflicts to the same key. A conflict arises
when two Syncbases attempt to update a value for the same key.

As an example of a potential conflict, consider updating the `numFortunesKey`
value concurrently on two services. If both services update the value from 1 to
2, it means two fortunes were added (one by each service), and the true value
should be 3. Instead, Syncbase will simply pick the latest value
written (2 in this scenario), and our data will be inconsistent. Adding a unique
identifier for each key prevents these conflicts since concurrent updates to the
same key never occur.

This makes the `Get` RPC slightly more complex. We use the `Scan` method with a
prefix to read the number of fortunes _each_ Syncbase has added (each number is
stored in a unique key, but Syncbase can perform scan on _prefixes_). We pick
one of the Syncbases at random, and then randomly pick one of the fortunes from
that Syncbase.

# Server

The server requires a small change: we need to pass a remote Syncbase name to
the service's `Make` function.

<!-- @defineServer @test @completer -->
```
mkdir -p $V_TUT/src/fortune/server
 cat - <<EOF >$V_TUT/src/fortune/server/main.go
package main

{{# helpers.codedim }}
import (
  "fmt"
  "flag"
  "fortune/ifc"
  "fortune/server/util"
  "fortune/service"
  "log"

  "v.io/v23"
  "v.io/v23/rpc"
  "v.io/x/ref/lib/signals"
  _ "v.io/x/ref/runtime/factories/generic"
)

var (
  serviceName = flag.String(
    "service-name", "",
    "Name for service in default mount table.")
  syncbaseName = flag.String(
    "sb-name", "",
    "Name of Syncbase service")
{{/ helpers.codedim }}
  remoteSyncbaseName = flag.String(
    "remote-sb-name", "",
    "Name of remote Syncbase service")
{{# helpers.codedim }}
)

func main() {
  ctx, shutdown := v23.Init()
  defer shutdown()
{{/ helpers.codedim }}
  fortune := ifc.FortuneServer(service.Make(ctx, *syncbaseName,  *remoteSyncbaseName))
{{# helpers.codedim }}

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
{{/ helpers.codedim }}

EOF
```


{{# helpers.hidden}}
<!-- @removeCodeDimMarkup @test @completer -->
```
sed -i 's/{{.*}}//' $V_TUT/src/fortune/server/main.go
sed -i 's/{{.*}}//' $V_TUT/src/fortune/service/service.go
```
{{/ helpers.hidden}}

Install the client and server:

<!-- @installClientServer @test @completer -->
```
go install fortune/server
go install fortune/client
```

# Run Your Code

We will start a Syncbase instance like before:

<!-- @startSb1 @test @completer @sleep -->
```
syncbased \
  --v23.credentials=$V_TUT/cred/alice \
  --v23.tcp.address=127.0.0.1:0 > $V_TUT/endpoint1  2> /dev/null &
TUT_PID_SB1=$!
while [ ! -s $V_TUT/endpoint1 ]; do sleep 1; done
```

Then we will start a server:

<!-- @startServer1 @test @completer @sleep -->
```
rm -f $V_TUT/server1.txt $V_TUT/server2.txt
$V_TUT/bin/server \
  --v23.credentials=$V_TUT/cred/alice \
  --v23.tcp.address=127.0.0.1:0 \
  --endpoint-file-name=$V_TUT/server1.txt \
  --sb-name=`cat $V_TUT/endpoint1 | grep 'ENDPOINT=' | cut -d'=' -f2` &> /dev/null &
TUT_PID_SERVER1=$!
```

Now, we will start a _second_ Syncbase. We will store the
endpoint in a different file `$V_TUT/endpoint2`:

<!-- @startSb2 @test @completer @sleep -->
```
syncbased \
  --v23.tcp.address=127.0.0.1:0 \
  --v23.credentials=$V_TUT/cred/alice > $V_TUT/endpoint2 2> /dev/null &
TUT_PID_SB2=$!
while [ ! -s $V_TUT/endpoint2 ]; do sleep 1; done
```

Now start another server, and pass the first Syncbase endpoint as
the remote Syncbase name:

<!-- @startServer2 @test @completer @sleep -->
```
$V_TUT/bin/server \
  --v23.credentials=$V_TUT/cred/alice \
  --v23.tcp.address=127.0.0.1:0 \
  --endpoint-file-name=$V_TUT/server2.txt \
  --sb-name=`cat $V_TUT/endpoint2 | grep 'ENDPOINT=' | cut -d'=' -f2` \
  --remote-sb-name=`cat $V_TUT/endpoint1 | grep 'ENDPOINT=' | cut -d'=' -f2` &> /dev/null &
TUT_PID_SERVER2=$!
```

We can now make RPC calls:

<!-- @initialClientCall @test @completer -->
```
$V_TUT/bin/client \
  --v23.credentials=$V_TUT/cred/alice \
  --server=`cat $V_TUT/server1.txt` \
  --add "The greatest risk is not taking one."

$V_TUT/bin/client \
  --v23.credentials=$V_TUT/cred/alice \
  --server=`cat $V_TUT/server2.txt` \
  --add "A new challenge is near."
```

Now get the fortunes back:

<!-- @getClientCall @test @completer -->
```
$V_TUT/bin/client \
  --v23.credentials=$V_TUT/cred/alice \
  --server=`cat $V_TUT/server1.txt`
```

Calling the `Get` RPC above enough times should return both the first and second
fortune eventually, even though the two fortunes were added to _different_
services. Syncbases exchange data in the fortune collection using the syncgroup
we set up.

# Cleanup

To clean up, kill the servers, Syncbase instances, and remove any temporary
files.

<!-- @cleanup @test @completer -->
```
kill_tut_process TUT_PID_SERVER1
kill_tut_process TUT_PID_SERVER2
kill_tut_process TUT_PID_SB1
kill_tut_process TUT_PID_SB2
rm -f $V_TUT/server1.txt
rm -f $V_TUT/server2.txt
```

# Summary

* You wrote a service which connects with Syncbase, creates a Syncbase
  collection, joins a syncgroup, and issues `Put` and `Get` calls to the
  collection.

* You launched multiple servers and Syncbases instances, issued client RPC calls
  to both, and watched the data between the two instances sync.

There is a lot more you can do with Syncbase. To dive deeper, see the [Syncbase
tutorial].

[local persistence tutorial]: /tutorials/syncbase/localPersist.html
[Syncbase tutorial]: /syncbase/tutorial/introduction.html
