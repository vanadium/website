= yaml =
title: Step-by-step Installation
toc: true
= yaml =

This document provides step-by-step instructions for installing Vanadium.

# System requirements

The instructions below assume you are using the [Bash][why-bash] shell.
<!-- @checkForBash @test -->
```
set | grep BASH > /dev/null || echo "Vanadium installation requires Bash."
```

In addition, they assume the following software packages are installed and
available in your `PATH`:

- curl
- [Go][go-install] 1.5 or above
- [Git] 2.4 or above

On OS X, you'll also need:

- [Homebrew][brew] package manager
- Full and up-to-date [Xcode]

## OS-specific setup details

For OS-specific setup details, consult these instructions:

- [Linux]
- [OS X][os-x]
- [Raspberry Pi][rpi]

# JIRI_ROOT environment variable

The Vanadium code is spread out across multiple git repositories. Though it's
possible to fetch the Vanadium Go code using standard `go get` commands, the
recommended approach is to use the `jiri` tool, which helps manage multiple
repositories.

Soon, we'll run a `bootstrap.sh` script that uses `jiri` to fetch the Vanadium
repositories. As such, we must first set the `JIRI_ROOT` environment variable.
Use an absolute path to a non-existent directory on the local filesystem. The
`bootstrap.sh` script will create this directory. (Remote filesystems such as
NFS are discouraged for performance reasons and to avoid git ENOKEY errors.)
<!-- @define_JIRI_ROOT @test -->
```
# Edit to taste.
export JIRI_ROOT=${HOME}/v23_root
```

Recommended for contributors: Add the line above to your `~/.bashrc` or similar.

# V23_RELEASE environment variable

The tutorials on this website use Go code from a particular subdirectory of
`JIRI_ROOT`. Tutorial users should set the `V23_RELEASE` environment variable to
this directory, as follows:
<!-- @define_V23_RELEASE @test -->
```
# Needed for tutorials only.
export V23_RELEASE=${JIRI_ROOT}/release/go
```

# Start from a clean slate

The `bootstrap.sh` script checks that the `JIRI_ROOT` directory does not yet
exist, then creates it. So, let's blow away `JIRI_ROOT` if it exists.

{{# helpers.warning }}
## Danger!
This will blow away your `JIRI_ROOT` directory, including any pending changes to
repositories in that directory. Make sure you're not deleting something
important.
{{/ helpers.warning }}
<!-- @define_rmrf_JIRI_ROOT @test -->
```
# WARNING: Make sure you're not deleting something important.
rm -rf $JIRI_ROOT
```

# Fetch Vanadium repositories

Run the `bootstrap.sh` script. This script will (1) install the `jiri` tool in
your `JIRI_ROOT` directory, (2) `git clone` a Vanadium-specific manifest
repository that configures `jiri` for the Vanadium project, and (3) use the
`jiri` tool to fetch all of the Vanadium repositories. Notably, this script will
not write to any files outside of the `JIRI_ROOT` directory.
<!-- @runBootstrapScript @test -->
```
# This can take several minutes.
curl -f https://vanadium.github.io/bootstrap.sh | bash
```

Add `$JIRI_ROOT/.jiri_root/scripts` to your `PATH`, for `jiri`:
<!-- @addDevtoolsToPath @test -->
```
export PATH=$JIRI_ROOT/.jiri_root/scripts:$PATH
```

Recommended for contributors: Add the line above to your `~/.bashrc` or similar.

# Additional prerequisites

Some components of Vanadium (e.g. Syncbase) have additional prerequisites,
including Snappy, LevelDB, and Node.js.

We recommend using the `jiri v23-profile` command to install all such
prerequisites. This command uses `apt-get` on Linux and `brew` on OS X. Note,
the `jiri` tool and its various plugins are located in
`$JIRI_ROOT/.jiri_root/scripts`.
<!-- @installBaseProfile @test -->
```
jiri v23-profile install base
```

The `jiri v23-profile install` command only writes to files under `JIRI_ROOT`,
i.e. it will not write to system folders such as those under `/usr`.

# Install Vanadium binaries

For simplicity, we use `jiri go` to install tools. The `jiri go` command simply
augments the `GOPATH` environment variable with the various paths to Vanadium Go
code under the `JIRI_ROOT` directory, and then runs the standard `go` tool.
<!-- @installVanadiumBinaries @test -->
```
# Install specific tools needed for the tutorials.
jiri go install v.io/x/ref/cmd/... v.io/x/ref/services/agent/... v.io/x/ref/services/mounttable/...
```

# Verifying installation

Compile all Go code:

    jiri go build v.io/...

Run all Go tests:

    jiri go test v.io/...

<!-- TODO: On OS X, this opens a bunch of warning popups about accepting
incoming connections. We should make all test servers listen on the loopback
address. -->

Install all Go binaries:

    jiri go install v.io/...

You should now have the following binaries available, among others:

- `$JIRI_ROOT/release/go/bin/mounttabled`
- `$JIRI_ROOT/release/go/bin/syncbased`
- `$JIRI_ROOT/release/go/bin/vrpc`

# Syncing the Vanadium repositories

To sync to the latest version of the Vanadium source code:

    jiri update

[why-bash]: /tutorials/faq.html#why-bash-
[go-install]: http://golang.org/doc/install
[git]: http://git-scm.com/
[brew]: http://brew.sh/
[xcode]: https://developer.apple.com/xcode/download/
[linux]: /installation/linux.html
[os-x]: /installation/os-x.html
[rpi]: /installation/rpi.html
