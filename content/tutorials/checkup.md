= yaml =
title: Internal Tutorial Checkup
layout: tutorial
sort: 98
toc: false
enumerable: false
= yaml =

A smoke test to see that `V23_RELEASE` is defined and provides access to crucial
Vanadium file assets.

This isn't meant to be an exhaustive test, just a quick check. It's used in
tests, tutorial preparation, etc.

<!-- @checkTutorialAssets @test @testui @completer -->
```
function bad_vanadium() {
  echo '
  Per https://vanadium.github.io/installation, either

    export V23_RELEASE={your installation directory}

  or do a fresh install.';
  exit 1;
}

[ -z "$V23_RELEASE" ] && { echo 'The environment variable V23_RELEASE is not defined.'; bad_vanadium; }

[ -x "$V23_RELEASE/bin/principal" ] || { echo 'The file $V23_RELEASE/bin/principal does not exist or is not executable.'; bad_vanadium; }
```
