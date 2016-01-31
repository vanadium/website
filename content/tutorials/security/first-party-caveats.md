= yaml =
title: Caveats
layout: tutorial
wherein: Carol delegates the access that Alice gave her to Diane.  Carol does so without bothering Alice and without leaking secrets.  Carol constrains Diane's power with caveats.
prerequisites: {scenario: d}
sort: 23
toc: true
= yaml =

# Start server with permissions

This tutorial uses the server with the Permissions authorizer
(described in the [permissions-authorizer] tutorial):

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


# Blessings as delegation

[Blessings][blessing] bind human-readable names (e.g.,
`alice:friend:bob`) to a principal (identified by its public
key). Principals are authorized based on these names.  For instance,
permissions provide a means of specifying authorization policy using a
list of patterns that match these names.


A principal can [bless] another principal by
extending one of its names and binding it to the other principal.
This notion enables _delegation_, wherein a principal with access to
a resource by virtue of one of its names passes on that access to
another principal.

Earlier, Alice blessed Bob as `alice:friend:bob` and Carol as
`alice:family:sister`.  With respect to the permissions given to the
server (via `--perms`), this means Carol can invoke both `Add` and `Get`, but Bob can
only invoke `Get`.

Introduce Diane:

<!-- @createDiane @test -->
```
$V_BIN/principal create --overwrite $V_TUT/cred/diane diane
```

As a new principal, Diane has no blessings (other than the default
'self' blessings), so she cannot read from (or write to) Alice's server:

<!-- @dianeCannotRead -->
```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/diane \
    --server `cat $V_TUT/server.txt`
```

Carol can extend her own blessing from Alice to provide Diane with
`alice:family:sister:guest`, thereby providing Diane with a blessing
that satisfies the permissions on Alice's server.

This allows Carol to share her access with Diane without involving
Alice and without any insecure workarounds (like sharing her private
key with Diane).

Three invocations of the `principal` command achieve this below.
* The first invocation fetches the blessing that Carol wishes to
  extend.
* The second uses that blessing to generate a new blessing for Diane.
* The third stores the new blessing, setting Diane up so that this
  blessing is presented to `alice`.

<!-- @carolDelegatesToDiane @test -->
```
$V_BIN/principal get \
    --v23.credentials $V_TUT/cred/carol \
    forpeer alice | \
        $V_BIN/principal bless \
            --v23.credentials $V_TUT/cred/carol \
            --with - \
            --for 24h \
            $V_TUT/cred/diane guest | \
                $V_BIN/principal set \
                   --v23.credentials $V_TUT/cred/diane \
                   forpeer - alice
```

![Carol blesses Diane as a guest](/images/tut/security05-carol-blesses-diane.svg)

With this blessing, Diane can invoke both `Get` and `Add` method:

<!-- @dianeCanNowAdd @test -->
```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/diane \
    --server `cat $V_TUT/server.txt`

$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/diane \
    --server `cat $V_TUT/server.txt` \
    --add 'Diane says hello!'
```

![Diane can Get and Add to the server](/images/tut/security06-carol-diane-succeed.svg)

# Caveats

Delegation via blessing allows Carol to grant Diane access to any
resources that Carol could access by virtue of her
`alice:family:sister` blessing.

This may make Diane as powerful as Carol, and Carol may not intend for
that. Carol can constrain the conditions under which Diane can use the
name `alice:family:sister:guest` by adding [_caveats_][caveats] to the
blessing.

Caveats are used to restrict the validity of a blessing to a scope,
such as invoking a particular method, communicating with a particular
peer, or any other arbitrary restriction. The API for generating
blessings (`v.io/v23/security.Principal.Bless`) allows for
these caveats to be specified.

The `principal` command-line tool supports adding an _expiry caveat_
to a blessing using the `--for {duration}` flag.

For example, Carol may bless Diane with the name
`alice:family:sister:guest` for only five seconds. The request to
`Add` will succeed if invoked immediately after the blessing is
generated but fail five seconds later:

<!-- @carolBlessesDianeAsGuest @test -->
```
$V_BIN/principal get \
    --v23.credentials $V_TUT/cred/carol \
    forpeer alice | \
        $V_BIN/principal bless \
            --v23.credentials $V_TUT/cred/carol \
            --with - \
			--for 5s \
            $V_TUT/cred/diane guest | \
                $V_BIN/principal set \
                    --v23.credentials $V_TUT/cred/diane \
                    forpeer - alice

$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/diane \
    --server `cat $V_TUT/server.txt` \
    --add 'Diane says hello again!'
```

![Carol blesses Diane with a 5-second caveat](/images/tut/security07-carol-blesses-diane-5sec.svg)

![Diane can get in temporarily](/images/tut/security08-diane-succeeds-5sec.svg)

Wait a few more seconds and this will fail:

```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/diane \
    --server `cat $V_TUT/server.txt` \
    --add 'Diane tries again.'
```

The second invocation of the `Add` method will fail with the error `does not
match permissions` since the `alice:family:sister:guest` blessing is no longer
valid and Diane did not present any other blessings that match the permissions
at the server.

![After 5 seconds, Diane cannot access the server](/images/tut/security09-diane-fails-5sec.svg)

We're done with the server for now.

<!-- @killServer @test -->
```
kill_tut_process TUT_PID_SERVER
```

# Summary

* Carol is able to delegate her access to Alice's servers via blessings.

* Blessings always have at least one caveat.

* An expiry caveat makes the blessing expire after a specified amount
  of time.

[bless]: /tutorials/security/principals-and-blessings.html#the-bless-operation
[blessing]: /glossary.html#blessing
[caveats]: /glossary.html#caveat
[permissions-authorizer]: /tutorials/security/permissions-authorizer.html
