= yaml =
title: Linux Prerequisites
toc: true
sort: 1
= yaml =

You need to install Git, curl, and Go.

The following commands should work on a Debian-based Linux distribution. Other
distributions might require use of `yum` instead of `apt-get`. Adapt as needed.

This document assumes that you are using the Bash shell.

# Git

Vanadium code is managed using Git. Learn more about Git setup on [GitHub].

```
sudo apt-get install git
```

# Curl

The install script uses curl to download some prerequisites.

```
sudo apt-get install curl
```

# Go

Vanadium is mostly implemented in Go. Learn more about Go installation on the
[Go website].

```
# Install the Go binaries in $HOME/go.
curl -f https://storage.googleapis.com/golang/go1.5.linux-amd64.tar.gz | tar -C $HOME -xzf -

# Modify your `.bashrc` file or its equivalent to faciliate Go usage.
cat - <<"EOF" >> $HOME/.bashrc
export GOROOT=$HOME/go
export PATH=$PATH:$GOROOT/bin
EOF
```

# You're all set

Return to the [Vanadium installation instructions][installation].

[GitHub]: https://help.github.com/articles/set-up-git
[Go website]: http://golang.org/doc/install
[installation]: /installation/
