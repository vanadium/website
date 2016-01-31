= yaml =
title: Installation
toc: true
= yaml =

This document explains how to install Vanadium (including Syncbase).

## System requirements

The instructions below assume that the following software packages are installed
and available in your `PATH`.

- curl
- [Go 1.5][go-install]
- [Git] 2.4 or above
- Full and up-to-date [Xcode], if on OS X

On OS X, you'll also need the [Homebrew package manager][brew] installed. You
can install it with:

    # Mac-only prerequisite.
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

## JIRI_ROOT environment variable

Set the `JIRI_ROOT` environment variable. Use an absolute path to a non-existent
directory on the local filesystem. (Remote filesystems such as NFS are
discouraged for performance reasons and to avoid git ENOKEY git errors.) The
setup script (see below) will create this directory, and will `git clone`
various Vanadium repositories into it.

    # Edit to taste.
    export JIRI_ROOT=${HOME}/vanadium

Recommended: Add the line above to your `~/.bashrc` or similar.

## Fetch Vanadium repositories

Run the setup script. This script will (1) install the `jiri` tool in your
`JIRI_ROOT` directory, (2) `git clone` a Vanadium-specific manifest repository
that configures `jiri` for the Vanadium project, and (3) use the `jiri` tool to
fetch all of the Vanadium repositories. Notably, this script will not write to
any files outside of the `JIRI_ROOT` directory.

    # This can take several minutes.
    curl https://v.io/bootstrap | bash

Add `$JIRI_ROOT/devtools/bin` to your `PATH`:

    export PATH=$PATH:$JIRI_ROOT/devtools/bin

Recommended: Add the line above to your `~/.bashrc` or similar.

## Prerequisites

Syncbase and various demo apps have some additional prerequisites, including
Snappy, LevelDB, and Node.js.

We recommend using the `jiri v23-profile` command to install all such
prerequisites. This command uses `apt-get` on Linux and `brew` on OS X. Note,
the `jiri` tool and its various plugins are located in
`$JIRI_ROOT/devtools/bin`.

    jiri v23-profile install base

The `jiri v23-profile install` command only writes to files under `JIRI_ROOT`,
i.e. it will not write to system folders such as those under `/usr`.

The base profile includes Syncbase and Go. To install Node.js (needed for the
[Todos demo app], among other things), run the following command:

    jiri v23-profile install nodejs

The `v23-profile` subcommand can be used to list installed and available
profiles as follows:

    jiri v23-profile list
    jiri v23-profile list --available

## Verifying installation

Compile all Go code:

    jiri go build v.io/...

Run all Go tests:

    jiri go test v.io/...

<!-- TODO: On OS X, this opens a bunch of warning popups about accepting
incoming connections. We should make all test servers listen on the loopback
address. -->

Install all Go binaries:

    jiri go install v.io/...

Note, the `jiri go` command simply augments the `GOPATH` environment variable
with the various paths to Vanadium Go code under the `JIRI_ROOT` directory, and
then runs the standard `go` tool.

You should now have the following binaries available, among others:

- `$JIRI_ROOT/release/go/bin/mounttabled`
- `$JIRI_ROOT/release/go/bin/syncbased`
- `$JIRI_ROOT/release/go/bin/vrpc`

## Syncing the Vanadium repositories

To sync to the latest version of the Vanadium source code:

    jiri update

## Extras

### Running the Syncbase Todos demo app

The [Todos demo app] is a web application that runs in Chrome. Before you can
run it, you must install the [Vanadium Chrome extension].

To run the app, follow the demo setup instructions here:
https://github.com/vanadium/todos/blob/master/demo.md

### JavaScript development

JavaScript development requires the `nacl` and `nodejs` profiles. As an
additional prerequisite, OS X users must have a full and up-to-date installation
of Xcode.

    jiri v23-profile install nacl nodejs

Build and test the JavaScript code:

    cd $JIRI_ROOT/release/javascript/core
    make test

Remove all JavaScript build artifacts:

    make clean

### Cross-compilation

The `jiri` tool supports cross-compilation.

    # For cross-compilation use:
    jiri v23-profile install --target=<arch>-<os> base
    jiri go --target=<arch>-<os> <command> <packages>

These commands configure the `GOPATH` and other environment variables so the
Vanadium libraries and binaries are built for the desired architecture.

[git]: http://git-scm.com/
[go-install]: http://golang.org/doc/install
[brew]: http://brew.sh/
[xcode]: https://developer.apple.com/xcode/download/
[todos demo app]: https://github.com/vanadium/todos
[Vanadium Chrome extension]: tools/vanadium-chrome-extension.html
