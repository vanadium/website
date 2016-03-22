= yaml =
title: Quick Installation
toc: false
= yaml =

Vanadium can be installed on Linux or OS X.
<!-- TODO(sadovsky): This is confusing for Android/iOS devs. -->

To install Vanadium, <a href="/sh/vanadium-install.sh"
download="vanadium-install.sh">download this script</a>, then [source] it:
<!-- @doInstallManually -->
```
source ~/Downloads/vanadium-install.sh
```

{{# helpers.hidden}}
Please [source] this script:
<!-- @doInstallViaCurl -->
```
source /dev/stdin <<< "$(curl -f -s https://v.io/sh/vanadium-install.sh)"
```
{{/ helpers.hidden}}

This script checks for prerequisites, then attempts to install Vanadium. It
takes about five minutes to run.

* If the script reports no errors, you're ready to try the [tutorials]!
* If it complains, please follow the [step-by-step instructions].

# What does the script do?

It runs all the steps from the [step-by-step instructions].

In particular, it checks for prerequisites, sets the `JIRI_ROOT` and
`VANADIUM_RELEASE` environment variables to `$HOME/vanadium` and
`$JIRI_ROOT/release/go` respectively, and installs Vanadium to the `JIRI_ROOT`
directory using the `bootstrap.sh` script.

The tutorials depend on `VANADIUM_RELEASE` to find the Vanadium installation, but
Vanadium itself doesn't depend on this variable.

Feel free to move `JIRI_ROOT` and `VANADIUM_RELEASE` elsewhere if you like.

[source]: /tutorials/faq.html#why-source-
[tutorials]: /tutorials/hello-world.html
[step-by-step instructions]: /installation/step-by-step.html
