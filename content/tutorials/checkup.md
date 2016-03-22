= yaml =
title: Internal Tutorial Checkup
layout: tutorial
sort: 98
toc: false
enumerable: false
= yaml =

A smoke test to see that `VANADIUM_RELEASE` is defined and provides access to crucial
Vanadium file assets.

This isn't meant to be an exhaustive test, just a quick check. It's used in
tests, tutorial preparation, etc.

<!-- @checkTutorialAssets @test @testui @completer -->
```
function bad_vanadium() {
  echo '
  Per https://vanadium.github.io/installation/, either

    export JIRI_ROOT={your installation directory}

  or do a fresh install.';
  exit 1;
}

[ -z "$VANADIUM_RELEASE" ] && { echo 'The environment variable VANADIUM_RELEASE is not defined.'; bad_vanadium; }

[ -x "$VANADIUM_RELEASE/bin/principal" ] || { echo 'The file $VANADIUM_RELEASE/bin/principal does not exist or is not executable.'; bad_vanadium; }
```
