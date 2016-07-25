= yaml =
title: Local Persistence
layout: tutorial
wherein: we persist the fortune teller service state in Syncbase.
prerequisites: {completer: syncbase-local-persist, scenario: b}
sort: 14
toc: true
= yaml =

# Introduction

This tutorial focuses on modifying the fortune application from the [basics
tutorial] to persist data in Syncbase.

Our Syncbase program will use the same architecture as our basic fortune
program. A __client__ will communicate with a __server__ using RPC, which will
call into a __service__.

Now however, instead of the service keeping a local database of fortunes in
memory, it will store the fortunes in Syncbase. Syncbase provides a __key-value
store__ API; our service can `Put` a __key__ associated with some __value__, and
`Get` the value back using the key.

Syncbase stores data in __databases__, which themselves hold __collections__. In
this tutorial we will create a new database and a new collection, and modify the
`Add` and `Get` RPC calls to use Syncbase instead of an in-memory
array.

# Modifying the Service

We will first modify the service to make calls into Syncbase instead of keeping
a local array of fortunes in memory. The implementation below connects to a
Syncbase instance, and modifies the `Add` and `Get` RPC calls to interact with
Syncbase.

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
  "sync"

  "v.io/v23/context"
  "v.io/v23/rpc"
{{/ helpers.codedim}}
  "v.io/v23/syncbase"
{{# helpers.codedim}}
)
{{/ helpers.codedim}}

// Constant names of different Syncbase entities.
const (
  fortuneDatabaseName   = "fortuneDb"
  fortuneCollectionName = "fortuneCollection"

  // A special key that specifies the number of fortunes.
  numFortunesKey = "numFortunes"
)

type impl struct {
  random        *rand.Rand   // To pick a random fortune
  mu            sync.RWMutex // To safely enable concurrent use.

  syncbaseName       string  // The Syncbase endpoint

  sbs syncbase.Service    // Handle to the Syncbase service
  d   syncbase.Database   // Handle to the fortunes database
  c   syncbase.Collection // Handle to the fortunes collection
}

// Makes an implementation.
func Make(ctx *context.T, syncbaseName string) ifc.FortuneServerMethods {
{{# helpers.codedim}}
  impl := &impl{
    random:             rand.New(rand.NewSource(99)),
{{/ helpers.codedim}}
    syncbaseName:       syncbaseName,
  }
  if err := impl.initSyncbase(ctx); err != nil {
    panic(err)
  }
{{# helpers.codedim}}
  return impl
}
{{/ helpers.codedim}}

// Initialize Syncbase by creating a new service, database and collection.
func (f *impl) initSyncbase(ctx *context.T) error {
  // Create a new service handle and a database to store the fortunes.
  sbs := syncbase.NewService(f.syncbaseName)
  d := sbs.Database(ctx, fortuneDatabaseName, nil)
  if err := d.Create(ctx, nil); err != nil {
      return err
  }

  // Create the collection where we store fortunes.
  c := d.Collection(ctx, fortuneCollectionName)
  if err := c.Create(ctx, nil); err != nil {
      return err
  }

{{# helpers.codedim}}
  f.sbs = sbs
  f.d = d
  f.c = c
  return nil
{{/ helpers.codedim}}
}

// Get RPC implementation. Returns a fortune retrieved from Syncbase.
func (f *impl) Get(ctx *context.T, _ rpc.ServerCall) (string, error) {
  f.mu.RLock()
  defer f.mu.RUnlock()

  var numKeys int
  if err := f.c.Get(ctx, numFortunesKey, &numKeys); err != nil || numKeys == 0 {
    return "[empty]", nil
  }

  // Get a random number in the range [0, numKeys) and convert it to a string;
  // this acts as the key in the sycnbase collection.
  key := strconv.Itoa(f.random.Intn(numKeys))
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

  var numKeys int
  if err := f.c.Get(ctx, numFortunesKey, &numKeys); err != nil {
    numKeys = 0
  }

  // Put the fortune into Syncbase.
  key := strconv.Itoa(numKeys)
  if err := f.c.Put(ctx, key, &fortune); err != nil {
    return err
  }

  // Update the number of keys.
  return f.c.Put(ctx, numFortunesKey, numKeys+1)
}

EOF
```

That's a lot of code! We will go through it function by function below.

## Make

Our `Make` function looks the same as it did before, but with an additional
field `syncbaseName`. Each Syncbase instance has a _name_; think of this as an
address for finding where the Syncbase is.

## Initializing Syncbase

Syncbase provides a storage service that can be shared between different apps.
Apps thus use RPC calls to the Syncbase service to create and access their own
databases.

Syncbase initialization occurs in `initSyncbase`. The high level steps are as
follows:

1. Create a new database.

2. Create a new collection. The collection
   stores the keys and values (in this case, our fortunes).

## Get and Add

Finally, we have our `Get` and `Add` functions. Let's break these down.

The first notable change is that we store the number of fortunes we have put
into Syncbase using a special key `numFortunesKey`. After getting the number of
fortunes we have in Syncbase, we must decide which fortune to return. We want a
random fortune based on the random number generator, but our keys have to be
strings; The `strconv.Itoa` function converts a random number to a string, which
we can use a key in Syncbase.

Next, we call `Get` on our collection; this call fetches the value into the
variable `value`. We check for errors and return the fortune if
everything looks alright.

The `Add` function works similarly, except we also increment the counter which
holds how many fortunes we have in our Syncbase.

# Server

We need to make a small change to our server. Namely, we need to pass in the
name of our Syncbase instance, so we can pass this to our service, which in turn
will use the name to connect to Syncbase. The core server logic remains
unchanged.

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
{{/ helpers.codedim }}
  syncbaseName = flag.String(
    "sb-name", "",
    "Name of Syncbase service")
{{# helpers.codedim }}
)

func main() {
  ctx, shutdown := v23.Init()
  defer shutdown()

{{/ helpers.codedim }}
  fortune := ifc.FortuneServer(service.Make(ctx, *syncbaseName))
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

Finally, install the client and server:

<!-- @installClientServer @test @completer -->
```
go install fortune/server
go install fortune/client
```

# Credentials

We will create a Syncbase instance tied to the fortune application and Alice's
devices. To authorize this, we make a new blessing `idp:o:fortune:alice`.

Syncbase requires this naming scheme for its blessings.

<!-- @makeCreds @test @completer -->
```
$V_BIN/principal create \
  --with-passphrase=false \
  --overwrite $V_TUT/cred/alice idp:o:fortune:alice
```

# Run Your Code

First, start a Syncbase instance. Like our server, Syncbase spits out an endpoint
which we write to a file. We then sleep until this endpoint appears, since we
need it to start our server.

<!-- @startSb1 @test @completer -->
```
$V_BIN/syncbased \
  --v23.tcp.address=127.0.0.1:0 \
  --v23.credentials=$V_TUT/cred/alice > $V_TUT/endpoint 2> /dev/null &
TUT_PID_SB1=$!
while [ ! -s $V_TUT/endpoint ]; do sleep 1; done
```

Then, start the server:

<!-- @startServer1 @test @completer @sleep -->
```
rm -f $V_TUT/server.txt
$V_TUT/bin/server \
  --v23.credentials=$V_TUT/cred/alice \
  --v23.tcp.address=127.0.0.1:0 \
  --endpoint-file-name=$V_TUT/server.txt \
  --sb-name=`cat $V_TUT/endpoint | grep 'ENDPOINT=' | cut -d'=' -f2` &> /dev/null &
TUT_PID_SERVER1=$!
```

We can now make RPC calls:

<!-- @initialClientCall @test @completer -->
```
$V_TUT/bin/client \
  --v23.credentials=$V_TUT/cred/alice \
  --server=`cat $V_TUT/server.txt` \
  --add='The greatest risk is not taking one.'
```

<!-- @secondClientCall @completer @test -->
```
$V_TUT/bin/client \
  --v23.credentials=$V_TUT/cred/alice \
  --server=`cat $V_TUT/server.txt`
```

The second call should return the fortune we just added. The fortune is
persisted in Syncbase.

# Cleanup

To clean up, kill the servers, Syncbase instances, and remove any temporary
files.

<!-- @cleanup @test @completer -->
```
kill_tut_process TUT_PID_SERVER1
kill_tut_process TUT_PID_SB1
```

# Summary

* You wrote a service which connects with Syncbase, creates a fortunes
  collection, and persists data in that collection.

There is a lot more you can do with Syncbase. To dive deeper, see the [Syncbase
tutorial].

[basics tutorial]: /tutorials/basics.html
[Syncbase tutorial]: /syncbase/tutorial/introduction.html
