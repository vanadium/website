= yaml =
title: OS X Prerequisites
sort: 2
= yaml =

These instructions were tested on a newly-installed copy of OS X Mavericks,
but they should work on most recent versions of OS X.

Some steps will not be necessary if you already have the associated software installed.

This document assumes that you are running the default shell, which is bash.

# OS X command line tools

These are the standard UNIX command line tools for development.
If you do not already have them, you can install them by attempting
to execute one of them.

For example, type the following command in a terminal window:
```
xcode-select --install
```

This will pop up a dialog window to install the command line tools:

![](/images/mac-command-dialog.png)

Click "Install".
If you want, there is also an option to install all of [Xcode][xcode],
but you do not need it to use Vanadium.

If you are using a version of OS X that is older than 10.9 you will need to get
the command line tools for your version
from https://developer.apple.com/downloads/ (login required).

# Git

You need `git` to install Vanadium.

The OS X command line tools include `git`, but usually an out-of-date copy.
We recommend you install the
[latest version from the Git website][git-install].

Read more about git setup at [github][git-setup].

# Go

Go can be installed with an OS X package installer:

1. Download the **darwin .pkg installer** for your system and OS version from https://golang.org/dl/
- Open it (double-click it in the Finder) and follow the instructions

The installer will install `go` in `/usr/local` and add `/usr/local/go/bin`
to your `PATH` (you will have to open a new terminal window for the change to take effect).

There are several alternative installation options at [golang.org][go-install].

# Node.JS (optional)

Node.JS is a JavaScript runtime environment for the command-line.
If you intend to develop in JavaScript, or go through the JavaScript tutorials,
you should install node.

1. Download the **Macintosh .pkg installer** from https://nodejs.org/download/
- Open it (double-click it in the Finder) and follow the instructions

The installer will install node in `/usr/local` and add `/usr/local/node/bin`
to your `PATH` (you will have to open a new terminal window for the change to take effect).

# You're all set

Return to the [Vanadium installation instructions][install].

[install]: /installation/index.html
[xcode]: https://developer.apple.com/xcode/
[go-install]: http://golang.org/doc/install
[git-install]: http://git-scm.com/downloads
[git-setup]: https://help.github.com/articles/set-up-git
