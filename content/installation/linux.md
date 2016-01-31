= yaml =
title: Linux Prerequisites
author: jregan@
sort: 1
= yaml =

You need curl, git and Go. (JavaScript developers also need node.)

The following example commands should work on a Debian-based Linux distribution.
Other distributions might require use of `yum` instead of `apt-get`. Adapt them
as needed.

```
# Vanadium is currently deployed by git cloning.
sudo apt-get install git

# Curl is used to download other components.
sudo apt-get install curl

# Fill $HOME/go with Go binaries.
( gosite=https://storage.googleapis.com/golang
  curl $gosite/go1.5.linux-amd64.tar.gz | tar -C $HOME -xzf - )

# Modify your `.profile` file or its equivalent to faciliate Go usage.
cat - <<"EOF" >> $HOME/.profile
export GOROOT=$HOME/go
export PATH=$PATH:$GOROOT/bin
EOF

# (Optional) Node.js is a JavaScript runtime environment.
( site=http://nodejs.org/dist
  curl $site/v0.12.2/node-v0.12.2-linux-x64.tar.gz |
    tar -C $HOME -xzf - )

# Modify your `.profile` file or its equivalent to facilitate node usage.
cat - <<"EOF" >> $HOME/.profile
export PATH=$PATH:$HOME/node-v0.12.2-linux-x64/bin
EOF
```

Read more about git setup at [github].

Read more about Go installation at the [Go site].

Read more about the optional Node.js installation at the [Node site].

Return to the [Vanadium installation instructions][install].

[install]: /installation/index.html
[Go site]: http://golang.org/doc/install
[Node site]: http://nodejs.org/download/
[github]:   https://help.github.com/articles/set-up-git
