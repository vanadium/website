= yaml =
title: Quick Install
toc: false
sort: 2
= yaml =

Vanadium is currently targetted to Linux and OS X based systems.

Please <a href="/sh/vanadium_install.sh" download="vanadium_install.sh">
download this script</a> then [source] it:
<!-- @doInstallManually -->
```
source ~/Downloads/vanadium_install.sh
```

{{# helpers.hidden}}
Please [source] this script:
<!-- @doInstallViaCurl -->
```
source /dev/stdin <<< "$(curl -s https://v.io/sh/vanadium_install.sh)"
```
{{/ helpers.hidden}}


The script checks for prerequisites and attempts installation.
It takes about five minutes.

* If the script reports no errors, you're ready to try the
[tutorials]!

* If it complains, please follow the
[detailed installation instructions][details].


# What does the script do?

The script checks for prerequisites, sets the `V23_RELEASE` environment
variable to `$HOME/v23_release`, wipes `$V23_RELEASE`, and fills it with
fresh Vanadium.

The tutorials depend on `V23_RELEASE` to find Vanadium, but Vanadium itself
doesn't use the variable.

If you keep Vanadium, you may want to edit your preferred environment
configuration "dot file" to add `$V23_RELEASE/bin` to your `PATH` variable. This
step, however, isn't necessary for the tutorials.

Feel free to move `v23_release` somewhere else if you like, and
redefine `V23_RELEASE` accordingly.


[details]: /installation/details.html
[tutorials]: /tutorials/hello-world.html
[source]: /tutorials/faq.html#why-source-
