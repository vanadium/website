= yaml =
title: OS X Prerequisites
toc: true
sort: 2
= yaml =

You need to install Homebrew, OS X command line tools, Git, and Go.

These instructions were tested on a fresh copy of OS X Mavericks, but they
should work on most recent versions of OS X.

This document assumes that you are using the default shell, which is Bash.

# Homebrew

[Homebrew] is a widely-used OS X package manager. We'll use it to install other
prerequisites.

```
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```

# OS X command line tools

These are the standard UNIX command line tools for development.

Enterthe following command in a terminal window:

```
xcode-select --install
```

This will pop up a dialog window to install the command line tools:

![](/images/os-x-xcode-dialog.png)

Click "Install".

Note, you can also install all of [Xcode], but that's not needed for Vanadium
unless you are using the Node.js libraries.

If you are using a version of OS X that is older than 10.9, you will need to get
the command line tools for your version from
https://developer.apple.com/downloads/ (login required).

# Git

Vanadium code is managed using Git. Learn more about Git setup on [GitHub].

The OS X command line tools include `git`, but usually an out-of-date copy.
We recommend you install the latest version using Homebrew.

```
brew install git
```

# Go

Go can be installed with an OS X package installer:

1. Download the **darwin .pkg installer** for your system and OS version from
   https://golang.org/dl/
2. Open it (double-click it in the Finder) and follow the instructions

The installer will install `go` in `/usr/local` and add `/usr/local/go/bin` to
your `PATH`. You will have to open a new terminal window for the `PATH` change
to take effect.

There are several alternative installation options described at
[golang.org][go-install].

# You're all set

Return to the [Vanadium installation instructions][installation].

[Homebrew]: http://brew.sh/
[xcode]: https://developer.apple.com/xcode/
[GitHub]: https://help.github.com/articles/set-up-git
[go-install]: http://golang.org/doc/install
[installation]: /installation/
