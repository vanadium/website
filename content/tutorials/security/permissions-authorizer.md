= yaml =
title: Permissions Authorizer
layout: tutorial
wherein: you meet a built-in authorizer that that lets Alice grant fine-grained access to Bob and Carol with simple lists of names.
prerequisites: {completer: permissions-authorizer, scenario: c}
sort: 22
toc: true
= yaml =

# Permissions policy

In addition to the [default authorization policy][default-auth], Vanadium
offers another built-in authorization policy based on the commonly used idea of
a permissions map.  Such an authorizer allows a wide range of policies
controllable via editing lists that are given to a server as flags - no need to
modify code.

{{# helpers.info }}

Vanadium also supports the use of a completely custom policy - the
procedure for building one is covered in the [custom authorizer
tutorial][custom-authorizer].

{{/ helpers.info }}

Permission maps define a list of blessings that should be given (or denied)
access to an object. All methods on objects can have _tags_ on them and the
access list used for the method is selected based on that tag.  This is
inspired by [Role Based Access Control].

To see how this works, assume Alice wants to let her family read and
write to her service but confine her friends to read operations only,
which don't change state.

To do so Alice defines two new tags, _Reader_ and _Writer_, and adds
them to the service VDL:

<!-- @fortuneInterfaceWithTags @test @completer -->
```
 cat - <<EOF >$V_TUT/src/fortune/ifc/fortune.vdl
package ifc

type MyTag string
const (
  Reader = MyTag("R")
  Writer = MyTag("W")
)

type Fortune interface {
  // Returns a random fortune.
  Get() (Fortune string | error) {Reader}
  // Adds a fortune to the set used by Get().
  Add(Fortune string) error {Writer}
}
EOF

VDLROOT=$VANADIUM_RELEASE/src/v.io/v23/vdlroot \
    VDLPATH=$V_TUT/src \
    $V_BIN/vdl generate --lang go $V_TUT/src/fortune/ifc
go build fortune/ifc
```

To exploit this a __new authorizer__ is needed - one
that honors permissions provided at the server
command line:

<!-- @permissionsAuthorizer @test @completer -->
```
 cat - <<EOF >$V_TUT/src/fortune/server/util/authorizer.go
package util

import (
  "bytes"
  "flag"
  "fortune/ifc"
  "v.io/v23/security"
  "v.io/v23/security/access"
  "v.io/v23/vdl"
)

var (
	perms = flag.String("perms", "",
      "JSON-encoded access.Permissions.")
)

func MakeAuthorizer() (authorizer security.Authorizer) {
  aMap, _ := access.ReadPermissions(
      bytes.NewBufferString(*perms))
  typ := vdl.TypeOf(ifc.Reader)
  authorizer, _ = access.PermissionsAuthorizer(aMap, typ)
  return
}
EOF

go install fortune/server
```

## A specific permissions map

Now restart the server with a *permissions map* that
allows __family__ to read and write and __friends__ to read only:

<!-- @startServerWithPerms @test @sleep -->
```
kill_tut_process TUT_PID_SERVER
$V_TUT/bin/server \
    --v23.credentials $V_TUT/cred/alice \
    --endpoint-file-name $V_TUT/server.txt \
    --perms '{"R": {"In": ["alice:family",
                           "alice:friend"]},
              "W": {"In": ["alice:family"]}}' &
TUT_PID_SERVER=$!
```

This takes the form of a map.  The keys are the service method labels
(`R` is an abbreviation for `Reader`, a label on `Get`), and the
values are lists of blessing patterns.  Principals with blessings matching
a pattern in the 'In' list can make the call.  An optional list called
`NotIn` specifies _exclusions_ from the `In` list (e.g., you might let in `family`,
but exclude `family:uncle`).

Patterns are slash-separated strings that may optionally end in a `$`.  The
pattern `alice:houseguest` will be matched by the names `alice:houseguest` and
its delegates `alice:houseguest:bob`, `alice:houseguest:bob:spouse` etc., but
not by the name `bob` or `alice:colleague` or prefixes of the pattern like
`alice`.  On the other hand, the pattern `alice:houseguest:$` would be matched
exactly by the name `alice:houseguest`.

## Impact on Bob and Carol

You can quickly confirm that Bob (already [blessed as a
`friend`][blessings]) can read:

<!-- @bobCanRead @test -->
```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/bob \
    --server `cat $V_TUT/server.txt`
```

But Bob cannot write (he's not family):

<!-- @bobCannotWrite -->
```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/bob \
    --server `cat $V_TUT/server.txt` \
    --add 'Bob is awesome.'
```

Introduce Carol:

<!-- @createCarol @test @completer -->
```
$V_BIN/principal create --with-passphrase=false --overwrite $V_TUT/cred/carol carol
```

At this point no request from Carol will succeed because Carol is
unknown to Alice.

Suppose Carol is Alice's sister and Alice gives Carol the blessing
`alice:family:sister`:

<!-- @aliceBlessCarolAsSister @test @completer -->
```
$V_BIN/principal bless \
    --v23.credentials $V_TUT/cred/alice \
    --for=24h $V_TUT/cred/carol family:sister | \
        $V_BIN/principal set \
            --v23.credentials $V_TUT/cred/carol \
            forpeer - alice
```

Now that Carol is seen as part of the family she'll be able to invoke
both `Get` and `Add`:

<!-- @clientIsCarol @test -->
```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/carol \
    --server `cat $V_TUT/server.txt`

$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/carol \
    --server `cat $V_TUT/server.txt` \
    --add 'Eat kale.'
```

![Alice's permissions policy allows Carol to Get and Add data to the server, but Bob can only Get](/images/tut/security04-alice-carol-succeed-bob-fails.svg)

We're done with the server now.

<!-- @killServer @test -->
```
kill_tut_process TUT_PID_SERVER
```

# Summary

* Vanadium provides a pre-built _Permissions authorizer_.

* Service methods defined in a VDL file can be tagged with _roles_,
  e.g. Reader and Writer.

* A server built with the Permissions authorizer accepts a flag mapping roles
  to lists of blessings.

* A client blessed to a role is able to call the corresponding methods.

[Role Based Access Control]: http://en.wikipedia.org/wiki/Role-based_access_control
[blessing]: /glossary.html#blessing
[cert-chain]: /glossary.html#certificate-chain
[custom-authorizer]: /tutorials/security/custom-authorizer.html
[principal]: /glossary.html#principal
[default-auth]: /tutorials/security/principals-and-blessings.html#default-authorization-policy
[blessings]: /tutorials/security/principals-and-blessings.html#blessings
[default-auth]: /tutorials/security/principals-and-blessings.html#default-authorization-policy
