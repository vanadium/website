= yaml =
title: Internal Tutorial Testing
layout: tutorial
sort: 1
toc: false
= yaml =

This page explains how to __test the tutorials__ against a local, development
branch of Vanadium.

In the overall external instruction sequence, this page replaces the external
[installation instructions](/installation/), allowing a Vanadium team member to
use their existing installation instead.

To run the tests, `$JIRI_ROOT` needs a value, and the binaries need to be in
place. Check your state:

<!-- @checkInstall -->
```
[ -z "${JIRI_ROOT:?'Must define JIRI_ROOT'}" ]
[ -x "$JIRI_ROOT/devtools/bin/jiri" ] || echo 'No jiri!'
[ -x "$JIRI_ROOT/release/go/bin/principal" ] || echo 'No bin!'
```

Development also requires Node.js. Install it as follows:
```
# Adds node to $JIRI_ROOT/environment/cout/node/bin. The Makefile adds this to
# $PATH automatically.
jiri v23-profile install nodejs
```

Since you're presumably considering a commit, be sure everything is up to date:

```
unset GOPATH
jiri update
jiri go install v.io/...
```

If this builds cleanly, you can meaningfully test the tutorials.

The tutorials don't use the `jiri` tool, so define the following
__tutorial environment__ to run the tests:

<!-- @defineLocalEnv @test @testui @buildjs -->
```
export V23_RELEASE=${JIRI_ROOT}/release/go

# Extract GOPATH from jiri utility.
export V23_GOPATH=`jiri go env GOPATH`
echo "V23_GOPATH=$V23_GOPATH"
```

That's it for prep.

Run all tutorial tests against your development branch like this:

```
cd ${JIRI_ROOT}/website
make test-tutorials
```

If those pass, you're good.

## Manual execution

If you're having trouble, you can do tutorials manually to pinpoint a problem.

Behave like a user following the instructions, but skip the Vanadium
installation step and start the tutorials with the [setup
page](/tutorials/setup.html). Due to the definitions above, the tutorial code
will run using your local development branch.

## Purely external execution

The command:

```
cd ${JIRI_ROOT}/website
make test-tutorials-external
```

This tests the tutorials __against Vanadium code freshly downloaded from the
external site to your `/tmp` directory__. It's a production test behaving like
an external user; _not_ a local test running against local changes. If you're
broken locally, this is a way to see if an external user is seeing a problem
too.
