= yaml =
title: Custom Authorizer
layout: tutorial
wherein: you craft a custom authorizer for Alice that lets family in at any time, but constrains friends to a time window.  This is an advanced tutorial.
prerequisites: {completer: custom-authorizer, scenario: d}
sort: 26
toc: true
= yaml =

# Introduction

The goal of this tutorial is to make a custom authorizer
and test it using some existing principals.

This command

```
ls $V_TUT/cred
```

should list (at least) `alice` and `bob` and `carol`.

The prerequisite script should have arranged for Bob to have the
blessing `alice:friend:bob` and Carol to have the blessing
`alice:family:sister`.

# Custom authorization policy

If the [Permissions authorizer][permissions-authorizer] and/or caveats (caveats
are discussed [later][first-party-caveats]) aren't sufficient for some purpose,
Vanadium applications can create their own arbitrarily complex policy by
implementing the [`security.Authorizer`][security.Authorizer] interface.

For example, this policy:

> *Alice's family can access the service at any time,
> but friends can access only during a particular time window.*

is implemented by this code:

<!-- @authorizerWithFriendWindow @test @completer -->
```
 cat - <<EOF >$V_TUT/src/fortune/server/util/authorizer.go
package util

import (
  "flag"
  "fmt"
  "time"
  "v.io/v23/context"
  "v.io/v23/security"
)

var (
  openStart  = flag.Int(
    "start", 12, "Hour when friends may start access.")
  openLength = flag.Int(
    "length", 1, "Number of hours the window stays open.")
)

type policy struct{}

func (policy) Authorize(ctx *context.T, call security.Call) error {
  var (
    client, _  = security.RemoteBlessingNames(ctx, call)
    hour, _, _ = time.Now().Clock()
    friendsOk  = hour >= *openStart &&
                 hour < (*openStart + *openLength)

    // Patterns on the blessings of authorized folks.
    friends = security.BlessingPattern("alice:friend")
    family  = security.BlessingPattern("alice:family")
  )
  // The client may present multiple blessings, check if any
  // of them satisfy the policy.
  if family.MatchedBy(client...) {
      // family is always okay, so this request is authorized.
      return nil
  }
  if friends.MatchedBy(client...) {
    // Friends only allowed in a given time window.
    if friendsOk {
      return nil
    }
    return fmt.Errorf(
        "friends like %v not authorized at this hour (%d)",
        client, hour)
  }
  // Nobody else is authorized
  return fmt.Errorf("not friend nor family, not authorized")
}

func MakeAuthorizer() security.Authorizer {
  return policy{}
}
EOF
go install fortune/server
```

Kill the running server (if any) and restart it so that it picks up this
new authorization policy:

<!-- @serverAsAliceWithFriendWindow @test @sleep -->
```
kill_tut_process TUT_PID_SERVER
$V_TUT/bin/server \
    --v23.credentials $V_TUT/cred/alice \
    --endpoint-file-name $V_TUT/server.txt \
    --start `date +%k` &
TUT_PID_SERVER=$!
```

Bob has the blessing `alice:friend:bob`, so RPCs will succeed - but
only in the given time window.

The following should work since `--start` is set
to the current hour:

<!-- @clientAsBob @test -->
```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/bob \
    --server `cat $V_TUT/server.txt`
```

![Bob's request to the server succeeds because it is during business hours](/images/tut/security10-bob-succeeds-biz-hours.svg)


Restart the server with a value of `--start` a few hours
in the future so that Bob's requests are rejected:

<!-- @serverRejectingBob -->
```
kill_tut_process TUT_PID_SERVER
$V_TUT/bin/server \
    --v23.credentials $V_TUT/cred/alice \
    --endpoint-file-name $V_TUT/server.txt \
    --start `expr \`date +%k\` + 3` &
TUT_PID_SERVER=$!
```

Bob is now rejected:

<!-- @bobIsRejected -->
```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/bob \
    --server `cat $V_TUT/server.txt`
```

![Bob's request to the server fails because it is outside of business hours](/images/tut/security11-bob-fails-biz-hours.svg)

Carol, on the other hand, has the blessing `alice:family:sister`.

Bob may be locked out, but Carol's requests work regardless of
the time:

<!-- @clientAsCarol @test -->
```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/carol \
    --server `cat $V_TUT/server.txt`
```

Feel free to review Carol's status with the [`principal dump`][principal-dump] command.

![Carol's request to the server succeeds](/images/tut/security12-alice-carol-succeed.svg)

We're done with the server for now.

<!-- @killServer @test -->
```
kill_tut_process TUT_PID_SERVER
```

# Summary

* A custom authorization policy allowed Alice to provide different
  access to friends and family.

* Alice can bless anyone as friend or family to give them access
  without modifying her server.

[principal-dump]: /tutorials/security/principals-and-blessings.html#principal-dump
[permissions-authorizer]: /tutorials/security/permissions-authorizer.html
[custom-authorizer]: /tutorials/security/custom-authorizer.html
[principals-and-blessings]: /tutorials/security/principals-and-blessings.html
[first-party-caveats]: /tutorials/security/first-party-caveats.html
[security.Authorizer]: https://vanadium.googlesource.com/release.go.v23/+/master/security/model.go#465
