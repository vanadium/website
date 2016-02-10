= yaml =
title: The Suffix - Part II
layout: tutorial
wherein: you add fine-grained security to control access to your multiple services. This is an advanced tutorial.
prerequisites: {completer: suffix-part2, scenario: e}
sort: 34
toc: true
= yaml =

# Introduction

In the suffix [Part I], you built a fortune server with multiple services.
For simplicity, this server used the [default authorizer] and only allowed
calls from the same principal.

In Part II, you will learn how to implement a fine-grained access control
policy for your services.

Let's add some requirements to our Part I example.

# Requirements

Your company, _Prophecies Inc_, needs a server to support its team of
prophetic _consultants_ - Cassandra, Nostradamus, etc.  Each
consultant needs its own data and customers.

 1. _Many services_: To support hiring new consultants, the server
    must be able to create fortune services on the fly, each with its
    own set of fortunes. [_done_]

 1. _Discovery_: Customers must be able to discover all the available
    services. [_done_]

 1. _Consultants_: Those blessed by the company.  Only they can
    create a service or add a fortune to it. [_new_]

 1. _Customers_: Those blessed by a particular consultant.  Only they
    can get a fortune from that consultant. [_new_]

 1. _Internships_: A consultant can delegate their ability to an
    apprentice fortune teller. [_new_]

To meet these requirements, we'll use a custom authorizer.

We _won't_ need a new dispatcher, or a new service implementation.


## New authorizer

In [Part I] and other tutorials we encountered the so-called [default authorizer]
and the [Permissions authorizer]. The requirements here are out of scope for
the default authorizer. The Permissions authorizer at the time of writing is
configured at server start time, before we know the names of the
services that the server will be running, so it falls short as well.

The following implementation of the [authorizer interface] attempts to
make a naming policy (both for services and blessings) that makes the
authorization scheme easy to understand.  One look at a blessing
name should make the access of the blessing obvious.

<!-- @newAuthorizer @test @completer -->
```
 cat - <<EOF >$V_TUT/src/fortune/server/util/authorizer.go
package util

import (
  "strings"
  "fortune/ifc"
  "errors"
  "v.io/v23/context"
  "v.io/v23/security"
  "v.io/v23/security/access"
)

type myAuthorizer struct {}

// The method being called - is it tagged?
func isTagged(call security.Call, tag string) (bool) {
  for _, mTag := range call.MethodTags() {
    if tag == mTag.RawString() {
      return true
    }
  }
  return false
}

func join(args ...string) security.BlessingPattern {
  return security.BlessingPattern(strings.Join(args, security.ChainSeparator))
}

func (my myAuthorizer) Authorize(ctx *context.T, call security.Call) error {
  if call.Suffix() == "" {
    return nil
  }
  var (
    serverBlessings    = security.LocalBlessingNames(ctx, call)
    clientBlessings, _ = security.RemoteBlessingNames(ctx, call)
    consultant         = join(serverBlessings[0], "consultant", call.Suffix())
    intern             = join(string(consultant), "intern")
    customer           = join(string(consultant), "cust")
  )
  if consultant.MakeNonExtendable().MatchedBy(clientBlessings...) {
    return nil
  }
  if intern.MatchedBy(clientBlessings...) {
    return nil
  }
  if (isTagged(call, string(ifc.Reader)) ||
      isTagged(call, string(access.Resolve))) && customer.MatchedBy(clientBlessings...) {
    return nil
  }

  return errors.New("access denied.")
}

func MakeAuthorizer() security.Authorizer {
  return &myAuthorizer {}
}
EOF
```

__Code walk__

In the body of `Authorize`, the first _if_ grants full access
to the `root` service to everyone. Remember that the `root` service
in our dispatcher is the ChildrenGlobber that publishes the name
of the fortune services in the server's namespace.

The second _if_ grants full access to a given service if the
client has a blessing of the form `{server}:consultant:{service}`.

The third _if_ allows interns the same sort of service-specific
access if their blessing has a particular pattern.

The fourth _if_ allows customers to get _read-only_ access, exploiting
the `Reader` annotation in the [fortune VDL] file.

# Try it

## New principals

First, initialize some principals.
<!-- @createProphIncPrincipal @test -->
```
$V_BIN/principal create --overwrite \
    $V_TUT/cred/prophInc prophInc
$V_BIN/principal create --overwrite \
    $V_TUT/cred/cassandra cassandra
$V_BIN/principal create --overwrite \
    $V_TUT/cred/nostradamus nostradamus
$V_BIN/principal create --overwrite \
    $V_TUT/cred/alice alice
$V_BIN/principal create --overwrite \
    $V_TUT/cred/bob bob
```

## Start the server

Fire up the server with the new authorizer code, and mount it in a
mount table:

<!-- @buildServer @test @completer -->
```
go install fortune/server
```

Start the fortune server.

<!-- @runServer @test @sleep -->
```
kill_tut_process TUT_PID_SERVER
$V_TUT/bin/server \
    --v23.credentials $V_TUT/cred/prophInc \
    --endpoint-file-name $V_TUT/server.txt &
TUT_PID_SERVER=$!
```

Start a mount table.

<!-- @startMountTable @test @sleep -->
```
PORT_MT=23000  # Pick an unused port.
kill_tut_process TUT_PID_MT
$V_BIN/mounttabled \
    --v23.credentials $V_TUT/cred/prophInc \
    --v23.tcp.address :$PORT_MT &
TUT_PID_MT=$!
export V23_NAMESPACE=/localhost:$PORT_MT
```

Add the fortune server to the mount table at the name `prophInc`:

<!-- @mountFortune @test -->
```
$V_BIN/namespace \
    --v23.credentials $V_TUT/cred/prophInc \
    mount prophInc `cat $V_TUT/server.txt` 2h
```

## Hire Cassandra

Try to run a client as Cassandra:

{{# helpers.warning }}
Expect it to fail.
{{/ helpers.warning }}

<!-- @firstTryAsCassandra -->
```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/cassandra \
    --server prophInc/cassandra
```

The error message will be something like: _Client doesn't trust the
server._ That's a runtime error - the code you wrote above hasn't even
been run yet.  Cassandra has no knowledege of Prophecies Inc.

You've [learned how to fix this][perform a blessing]; Cassandra needs
a blessing from the server's principal:

<!-- @blessCassandra @test -->
```
$V_BIN/principal bless \
    --v23.credentials $V_TUT/cred/prophInc \
    --for=24h $V_TUT/cred/cassandra consultant:cassandra | \
        $V_BIN/principal set \
            --v23.credentials $V_TUT/cred/cassandra \
            forpeer - prophInc
```

Try again.


<!-- @secondTryAsCassandra -->
```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/cassandra \
    --server prophInc/cassandra
```

That works.

Likewise, the client should be able to write to that service:

<!-- @writingFails -->
```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/cassandra \
    --server prophInc/cassandra \
    --add 'Do not visit Sparta!'
```

# More use cases

![](/images/tut/suffix-scenario.svg)


## Hire Nostradamus

What can Nostradamus do at this point?
Nothing, since the company hasn't blessed him.
Let's do that:

<!-- @blessNostradamus @test -->
```
$V_BIN/principal bless \
  --v23.credentials $V_TUT/cred/prophInc \
  --for=24h $V_TUT/cred/nostradamus consultant:nostradamus |\
        $V_BIN/principal set \
            --v23.credentials $V_TUT/cred/nostradamus \
            forpeer - prophInc
```

Now verify that Nostradamus can read/write his own service:

<!-- @firstTryAsNostradamus @test -->
```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/nostradamus \
    --server prophInc/nostradamus
```

But Nostradamus _should not be able to read his colleague Cassandra's service_:

{{# helpers.warning }}
This should fail.
{{/ helpers.warning }}

<!-- @secondTryAsNostradamus  -->
```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/nostradamus \
    --server prophInc/cassandra
```

Also, notice that Nostradadus doesn't see cassandra in the namespace.

<!-- @globServer @test -->
```
$V_BIN/namespace \
    --v23.credentials $V_TUT/cred/nostradamus \
    glob "prophInc/*"
```

## Interns

Suppose Cassandra needs some vacation, and wants Alice to take over.
Alice currently has no blessings relevant to the running service, so
can do nothing.

Cassandra can change this by hiring Alice as an intern.  Cassandra can
do so without access to the credentials belonging to Prophesies
Inc.

<!-- @cassandraDelegatesToAlice @test -->
```
$V_BIN/principal get \
   --v23.credentials $V_TUT/cred/cassandra \
   forpeer prophInc | \
       $V_BIN/principal bless \
         --v23.credentials $V_TUT/cred/cassandra \
         --with=- --for=24h $V_TUT/cred/alice intern:alice |\
               $V_BIN/principal set \
                  --v23.credentials $V_TUT/cred/alice \
                  forpeer - prophInc
```

Now, like Cassandra, Alice can read and write Cassandra's service:

<!-- @firstTryAsAlice @test -->
```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/alice \
    --server prophInc/cassandra
```

But Alice cannot access Nostradamus' service:
{{# helpers.warning }}
This should fail.
{{/ helpers.warning }}

<!-- @secondTryAsAlice  -->
```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/alice \
    --server prophInc/nostradamus
```

And Alice can only see cassandra in the namespace:
<!-- @globServer @test -->
```
$V_BIN/namespace \
    --v23.credentials $V_TUT/cred/alice \
    glob "prophInc/*"
```

## Customers

Of the principals created for this tutorial, only Bob is untouched.

Make him a customer to Nostradamus:

<!-- @bobIsCustomerOfNostradamus @test -->
```
$V_BIN/principal get \
   --v23.credentials $V_TUT/cred/nostradamus \
   forpeer prophInc | \
       $V_BIN/principal bless \
         --v23.credentials $V_TUT/cred/nostradamus \
         --with=- --for=24h $V_TUT/cred/bob cust:bob | \
               $V_BIN/principal set \
                  --v23.credentials $V_TUT/cred/bob \
                  forpeer - prophInc
```

Verify that Bob can get fortunes from Nostradamus:

<!-- @bobCanRead @test -->
```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/bob \
    --server prophInc/nostradamus
```

But that he cannot write to Nostradamus' service:
{{# helpers.warning }}
This should fail.
{{/ helpers.warning }}


<!-- @bobCannotWrite  -->
```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/bob \
    --server prophInc/nostradamus \
	--add 'Bob is so Cool!'
```

Verify on your own that Bob is unable to access Cassandra's service.

{{# helpers.warning }}
This should fail.
{{/ helpers.warning }}

<!-- @bobCannotReadCassandra -->
```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/bob \
    --server prophInc/cassandra
```

As a customer, Bob can only see nostradamus:
<!-- @bobOnlySeesNostradamus @test -->
```
$V_BIN/namespace \
    --v23.credentials $V_TUT/cred/bob \
    glob "prophInc/*"
```
# Exercises

## Cassandra peeks at Nostradamus

Alice is Cassandra's intern.

What would it take to make her _also_ a customer of Nostradamus?
That is, what needs to happen to make the following command work?


<!-- @aliceReadsNostradamus  -->
```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/alice \
    --server prophInc/nostradamus
```

## Nostradamus cheats

Can Nostradamus bless himself to gain access to Cassandra's data?

What if he got 'hired' with the name `consultant:cassandra2`?

## Internship

Can an intern have an intern?  If so, can you prevent it?

Can an intern accept a new customer?

# Cleanup

<!-- @cleanup @test -->
```
kill_tut_process TUT_PID_SERVER
kill_tut_process TUT_PID_MT
unset V23_NAMESPACE
```

# Summary

* In Vanadium, authorization boils down to simple string comparisons.
  Supporting infrastructure assures the strings cannot be forged.

[Part I]: /tutorials/naming/suffix-part1.html
[default authorizer]: /tutorials/security/principals-and-blessings.html#default-authorization-policy
[perform a blessing]: /tutorials/security/principals-and-blessings.html#blessings
[Permissions authorizer]: /tutorials/security/permissions-authorizer.html
[fortune VDL]: /tutorials/security/permissions-authorizer.html#permissions-policy
[authorizer interface]: https://godoc.org/v.io/v23/security#Authorizer
[v23_namespace]: /tutorials/naming/mount-table.html#the-namespace-variable
