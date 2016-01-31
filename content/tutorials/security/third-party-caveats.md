= yaml =
title: Third-party Caveats
layout: tutorial
wherein: you arrange for your lawyer to get access to your "documents", then revoke that access.
prerequisites: {scenario: d, also: {account: true}}
sort: 24
toc: true
= yaml =

# Introduction

Earlier you [learned][first-party caveats] how to add [caveats] to a
[blessing] to restrict its validity.  For example, one can make a
blessing expire after a few minutes, or restrict it to work only when
accessing a particular _method_ on a service. These conditions are
validated by the _server_ before allowing the client to invoke a
method.

This tutorial introduces
[_third-party caveats_][third-party caveat]. The restrictions encoded
in the caveat are validated by a third party that issues a proof of
validity called a [discharge].  In this context the third party is
called a [discharger].

The server simply verifies the discharges accompanying a request
instead of having to validate arbitrary conditions.

This tutorial will use a third-party caveat and a particular
discharger to demonstrate a _revocable_ blessing.

## Tutorial sequence

Imagine that Alice is your lawyer, and you want her to access your
data stored in [Google Drive].

Vanadium is too new to be supported by Google Drive, so we'll
use a stand-in - your fortune service.  Your stand-in will,
however, demand real authentication via Google.

You will:

* __Seek a blessing__ associated with a real [Google account] (yours).

* __Run a fortune service__ as a new [principal] named CheapDrive.

  This local stand-in for a [Google Drive] will demand that its
  clients wield a blessing from the holder of a Google account.
  You sought such a blessing, so you can use the service.

* __Extend your blessing to Alice.__

  Alice can then access _your_ data at CheapDrive.

* __Revoke the blessing__.

  Verify Alice no longer has access.

The twist here is that Alice never needs a Google account, and you
give her access without contacting Google.

Google is contacted, however, to confirm her access and to revoke it.

# Seek a blessing

Set up some credentials:

<!-- @initializeCredentials @test -->
```
$V_BIN/principal create --overwrite $V_TUT/cred/cheapDrive cheapDrive
$V_BIN/principal create --overwrite $V_TUT/cred/alice alice
$V_BIN/principal create --overwrite $V_TUT/cred/$USER $USER
```

Now you (really you) will use your Google account to _seek a blessing_:

<!-- @seekBlessing -->
```
$V_BIN/principal \
    --v23.credentials $V_TUT/cred/$USER \
    seekblessings --from https://dev.v.io/auth/google
```

A browser will start up, log you into Google, ask you to approve
Vanadium access to your identity (details
[here](#seeking-a-blessing)), and show you a web form.

In the __Blessing Name__ section, in the __extension__ field (read
about extensions [here](#the-extension)) please enter:

<!-- @extensionText -->
```
docs
```

Leave everything else in its default state, click __BLESS__, and
close the browser window.

The appendix provides a
[summary of what just happened](#seeking-a-blessing).

## Examine it

If all went well, you've just stored a blessing from `dev.v.io` to
your credentials directory (`$V_TUT/cred/$USER`).

Examine the blessing's name as follows:

<!-- @getUsersBlessingName @test -->
```
blessingName=`$V_BIN/principal \
    --v23.credentials $V_TUT/cred/$USER \
    get default -names`
echo $blessingName
```

It should look like:

{{# helpers.codeoutput }}
dev.v.io:u:${yourEmailAddress}:docs
{{/ helpers.codeoutput }}

Blessing names are unforgeable.  Anyone who recognizes `dev.v.io` (the
[blessing root]) will know that someone blessed with a name in this
form has either directly authenticated with Google as
`${yourEmailAddress}`, or was blessed by someone who did.

By default, this blessing comes with a _third-party caveat_ that
enables revocation.

Report the caveat on this blessing using a command
[introduced earlier][get-caveats-command]:

<!-- @getTheCaveat @test -->
```
$V_BIN/principal \
    --v23.credentials $V_TUT/cred/$USER \
    get forpeer -caveats=$blessingName ...
```

The output should be something like

{{# helpers.codeoutput }}
ThirdPartyCaveat:
Requires discharge from /ns.dev.v.io:8101/identity/dev.v.io:u/discharger
{{/ helpers.codeoutput }}

This reports the address of the caveat's [discharger].

The discharger issues a [discharge][discharge] - proof that the
third-party caveat is valid. In this case the third-party caveat is a
revocation caveat and therefore the discharger issues a discharge only
if the corresponding blessing has not been revoked.  The revoked state
is simply a bit in a database behind the discharger.

This discharger is consulted on every attempt to use the blessing
(modulo [discharge caching][discharge]).

This will be demonstrated shortly.

# Communicate

As mentioned [above](#tutorial-sequence), CheapDrive is going to run a
server, and various clients will try to use it.

## Recognition

In previous tutorials, the server's principal in one form or another
_blessed_ clients.  Those blessed automatically _recognize_ their
blessers, and blessers honor the blessings they issue.

In this tutorial _the communicating peers won't be blessing each
other_.

As a Vanadium principal will ignore communication from an
_unrecognized_ peer, we have to arrange for _recognition_.


### Your recognized roots

List the principals that `$USER` recognizes:

<!-- @dumpUsersRecognition1 @test -->
```
$V_BIN/principal \
    --v23.credentials $V_TUT/cred/$USER \
    get recognizedroots
```

This command shows that principal `$USER` recognizes two principals -
itself, and `dev.v.io`.

Self recognition of of the name corresponding to the value of `$USER`
was established with the `principal create` command above.  This is an
example of a [self-blessing].  Recognition of `dev.v.io` happened as a
result of seeking a blessing from `dev.v.io`.

Now, let _you_, as `$USER`, recognize CheapDrive so that you can make
requests to it later:

<!-- @userRecognizesCheapDrive @test -->
```
$V_BIN/principal \
    --v23.credentials $V_TUT/cred/cheapDrive \
    get default | \
        $V_BIN/principal \
            --v23.credentials $V_TUT/cred/$USER \
            recognize -
```

This command says:

> Extract the blessing `cheapDrive` presents to clients, and then
> arrange for `$USER` to recognize the principal that created said
> blessing.

In this case, the blessing creator was CheapDrive itself.

Confirm that `cheapDrive` now appears in the list of roots recognized by
`$USER`:

<!-- @dumpUsersRecognition2 @test -->
```
$V_BIN/principal \
    --v23.credentials $V_TUT/cred/$USER \
    get recognizedroots
```

The key reported for `cheapDrive` should match the output of this
command:

<!-- @dumpCheapDrivesKey @test -->
```
$V_BIN/principal \
    --v23.credentials $V_TUT/cred/cheapDrive \
    get publickey -pretty
```

### Alice's recognized roots

Likewise, let Alice recognize CheapDrive:

<!-- @aliceRecognizesCheapDrive @test -->
```
$V_BIN/principal \
    --v23.credentials $V_TUT/cred/cheapDrive \
    get default | \
        $V_BIN/principal \
            --v23.credentials $V_TUT/cred/alice \
            recognize -
```

Alice now recognizes CheapDrive.  CheapDrive has __not__ blessed
Alice.  Nothing has happened that could be construed as delegation.

### CheapDrive's recognized roots

Finally, let CheapDrive recognize `dev.v.io`:

<!-- @cheapDriveRecognizesGoogle @test -->
```
$V_BIN/principal \
    --v23.credentials $V_TUT/cred/$USER \
    get default |
        $V_BIN/principal \
            --v23.credentials $V_TUT/cred/cheapDrive \
            recognize -
```

This last command relies on the fact that `$USER`'s default blessing
came from `dev.v.io`.

These recognition steps will make more sense shortly.  The recognition
graph, excluding self-recognition, is shown below.

![Current recognition graph](/images/tut/security13-recognition-graph.svg)


## Permissions

In previous tutorials communicating parties blessed each other.

That won't be the case here.  CheapDrive won't bless anyone.

Instead, CheapDrive will configure, via a command line flag, a
[Permissions Authorizer] that allows a specific Google user (you) to
securely access CheapDrive's service.

Use the `$blessingName` you sought above to define a [Permissions]
specification for reading:

<!-- @definePermissions @test -->
```
perms=`echo {\"R\": {\"In\": [\"$blessingName\"]}}`
echo $perms
```

Finally, start a server with those permissions.

<!-- @startServer  -->
```
kill_tut_process TUT_PID_SERVER
$V_TUT/bin/server \
    --v23.credentials $V_TUT/cred/cheapDrive \
    --endpoint-file-name $V_TUT/server.txt \
    --perms "$perms" &
TUT_PID_SERVER=$!
```

## Make requests

Make a request as You:

<!-- @getYourFortune -->
```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/$USER \
    --server `cat $V_TUT/server.txt`
```

This request succeeds because the server was configured to accept your
blessing, and because the server recognizes the root of that blessing
(`dev.v.io`).

Now make a request as (your lawyer) Alice:

{{# helpers.warning }}
This request should fail.
{{/ helpers.warning }}

<!-- @aliceTriesAndFails -->
```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/alice \
    --server `cat $V_TUT/server.txt`
```

This fails because Alice lacks the proper blessing.

## Bless Alice

Extend your `dev.v.io` blessing to Alice using
the [extension](#the-extension) `lawyer`:

<!-- @blessYourLawyer @test -->
```
$V_BIN/principal \
    --v23.credentials $V_TUT/cred/$USER \
    get default | \
        $V_BIN/principal \
            --v23.credentials $V_TUT/cred/$USER \
            bless --with=- --for=24h $V_TUT/cred/alice lawyer | \
                $V_BIN/principal \
                   --v23.credentials $V_TUT/cred/alice \
                   set forpeer - cheapDrive
```

Take a look at Alice's new blessing name:

<!-- @blessYourLawyer @test -->
```
$V_BIN/principal get peermap \
    --v23.credentials $V_TUT/cred/alice | grep cheapDrive
```

The choice of `lawyer` as part of the name here will be shared only
with CheapDrive servers, since that was the argument of `forpeer`.

This blessing, and its hint that Alice is your lawyer, will not be
presented to any other peer that Alice interacts with.

Now Alice can examine your CheapDrive data:

<!-- @aliceSucceeds -->
```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/alice \
    --server `cat $V_TUT/server.txt`
```

As long as Alice doesn't lose her credentials data, her requests will
continue to work - until you revoke the blessing.

## Revoke the blessing

Visit [dev.v.io/auth], and click __YOUR BLESSINGS__.

Find the blessing you created in the
[Seek a Blessing](#seek-a-blessing) step above, and click its
__Revoke__ button.

Alice should no longer be able to read, i.e. this command should fail:

<!-- @aliceShouldFail -->
```
$V_TUT/bin/client \
    --v23.credentials $V_TUT/cred/alice \
    --server `cat $V_TUT/server.txt`
```

## Cleanup

We're done with the server.

<!-- @killServer @test -->
```
kill_tut_process TUT_PID_SERVER
```

The blessing you obtained above, which you've just rendered useless,
nevertheless still consumes a tiny bit of disk space in
`$V_TUT/cred/$USER`.  Feel free to delete that, along with `$V_TUT` and
everything below it.

The record of the revoked blessing at [dev.v.io/auth] will eventually
be removed from Google's servers. Its not possible to un-revoke it, so
there's no reason to keep it.

If you wish to revoke the [Oauth] access you gave to Vanadium (it was
only needed to create a blessing for this tutorial), visit your
[Google settings], click on __Vanadium__, and click __Revoke access__.


# Summary

* Third-party caveats are a means to add arbitrary conditions to
  authorization.

* The server doesn't bear the cost of their discharge - the third
  party does.

* A particular example of a third-party caveat is a revocable caveat,
  where some third party holds the revocation bit.

* Here we used Google to both broker authentication (convert your
  Google login into a blessing protecting what could have been your
  Google data) and to hold a bit allowing that blessing to be revoked.

* "Cheap Drive" here was a stand-in for Google Drive - but the example
  is unchanged if we imagine any cloud storage service that
  incorporates Vanadium.  The Google login _controls only the
  blessing_, not the service protected by the blessing.

* You were able to extend your "Google blessing" to someone who didn't
  have a Google account to allow them to access your data.

* A different company could set up its own identity service to do
  the same.


# Exercises

## Skip recognition

Start the tutorial again, and skip some of the recognitions steps.

Do the failures make sense?

## Seek multiple blessings

Use a different extension for each one.

In this way, you can retain a blessing for your own use, while
revoking the `docs` blessing.

## The intern

Can Alice give her intern Bob access to your data?

Does revocation of Alice's access also turn off Bob's access?


# Appendix

## Seeking a blessing


Here's what happened [above](#seek-a-blessing) when you sought a blessing.

The `principal` program implicitly started listing on an [endpoint],
then encoded that endpoint as a parameter in a URL based on the
`--from` argument, then launched a browser loading that URL.  The
`principal` program then waited for a Vanadium RPC to appear on
the endpoint.

Behind the URL is an [identity provider], an instance of Vanadium's
[identityd], [self-blessed][self-blessing] with the name `dev.v.io`.

A web server associated with that provider told the browser to send
its user - _you_ - to Google for login, then to an [Oauth] grant
screen.  After completing that, it gave you a form for creating a
blessing.  When you clicked __Bless__, the form was submitted, and the
provider sent an RPC with the resulting blessing to the aforementioned
endpoint, to be stored in `$V_TUT/cred/$USER`.

For details, see this
[document describing the Vanadium identity service][identityd].

## The extension

In the context of _extending a blessing_, the _extension_ is just the
string appended to the _existing_ blessing name to create the name
given to the _new_ blessing.

It's handy to think of this as a categorization mechanism, like
directories.

[Above](#seek-a-blessing) you used `docs` as the extension in a
blessing you intended to extend to Alice so that she could access your
_documents_.

If the blessing had been intended to allow access to your email, you
might have used the extension `email`.

When you further extended the blessing to Alice, you specified
`lawyer` as the extension, so her blessing ending with `docs:lawyer`.

If Alice extended that blessing to her intern Bob, it would likely end
with `docs:lawyer:intern:bob`.  You might also extend a blessing to
`family` or `friends`, as Alice did in
[earlier tutorials][first-party caveats].

Blessing names show up in server logs, facilitating access analysis.

[Permissions Authorizer]: /tutorials/security/permissions-authorizer.html
[blessing root]: /glossary.html#blessing-root
[blessing]: /glossary.html#blessing
[caveat.vdl]: https://github.com/vanadium/go.v23/blob/master/security/caveat.vdl
[caveats]: /glossary.html#caveat
[dev.v.io/auth]: https://dev.v.io/auth
[discharge]: /glossary.html#discharge
[discharger]: /glossary.html#discharger
[endpoint]: /glossary.html#endpoint
[first-party caveats]: /tutorials/security/first-party-caveats.html
[get-caveats-command]: /tutorials/security/principals-and-blessings.html#caveats
[Google account]: https://accounts.google.com
[google drive]: https://developers.google.com/drive/web
[google settings]: https://security.google.com/settings/security/permissions
[identity provider]: /glossary.html#identity-provider
[identityd]: /designdocs/identity-service.html
[oauth]: https://developers.google.com/accounts/docs/OAuth2InstalledApp
[permissions]: /glossary.html#permissions
[principal]: /glossary.html#principal
[self-blessing]: /glossary.html#self-blessing
[third-party caveat]: /glossary.html#third-party-caveat
