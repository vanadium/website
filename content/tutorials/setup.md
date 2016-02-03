= yaml =
title: Tutorial Environment Setup
layout: tutorial
sort: 99
toc: false
enumerable: false
= yaml =

You don't need to read this, unless you were sent here with a suggestion to
start a second tutorial terminal, likely to keep the output from multiple
processes easier to read.

In addition to the `$V23_RELEASE` variable defined by [installation], every
terminal window used in a tutorial must run the environment definition script
below.

If you follow the prerequisite instructions at the beginning of a tutorial,
you'll implicitly run the script on this page, and you'll run commands from
earlier tutorials that create the _files_ needed by your current tutorial.

A second terminal won't need to recreate the files, but will need the [bash]
environment defined below.

<!-- @envVars @buildjs @test @testui @completer -->
```
# If JIRI_ROOT or V23_RELEASE are not defined, set them to the default values
# from the installation instructions and hope for the best.

[ -z "$JIRI_ROOT" ] && export JIRI_ROOT=${HOME}/v23_root
[ -z "$V23_RELEASE" ] && export V23_RELEASE=${JIRI_ROOT}/release/go

# All files created by the tutorial will be placed in $V_TUT. It is a disposable
# workspace, easy to recreate.
export V_TUT=${V_TUT-$HOME/v23_tutorial}

# V_BIN is a convenience for running Vanadium binaries. It avoids the need to
# modify your PATH or to be 'in' a particular directory when doing the
# tutorials.
export V_BIN=${V23_RELEASE}/bin

# For the shell doing the tutorials, GOPATH must include both Vanadium and the
# code created as a result of doing the tutorials. To avoid trouble with
# accumulation, $GOPATH is intentionally omitted from the right hand side (any
# existing value is ignored).
if [ -n "$V23_GOPATH" ]; then
  # Use the contributor's GOPATH rather than the release. See ../testing.md.
  export GOPATH=$V_TUT:${V23_GOPATH}
else
  export GOPATH=$V_TUT:`jiri go env GOPATH`
fi

# HISTCONTROL set as follows excludes long file creation commands used in
# tutorials from your shell history.
HISTCONTROL=ignorespace

# A convenience for killing tutorial processes
function kill_tut_process() {
  eval local pid=\$$1
  if [ -n "$pid" ]; then
    kill $pid || true
    wait $pid || true
    eval unset $1
  fi
}
```

[installation]: /installation/
[bash]: /tutorials/faq.html#why-bash-
