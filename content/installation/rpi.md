= yaml =
title: Raspberry Pi
author: ashankar@
toc: true
sort: 3
= yaml =

Vanadium can be used to write software for [RaspberryPi]s. This page details
how to set things up so you can build and run Vanadium [Go] binaries on them.

# Prerequisites

You need a [RaspberryPi] with an installed operating system. See [installation
instructions at raspberrypi.org][rpi-documentation].
Advanced or adventurous users may want to install [Raspian] directly.

# Building on a RaspberryPi

You could use the [RaspberryPi] as your complete development environment -
write code, compile it and run it all on the Pi. To do that you will:

1. Need the [Go] compiler. Starting with Go 1.6, the official release includes
   binaries that work on the Pi (the armv6l architecture).
2. Download the Vanadium sources:
   ```
   export GOPATH=$HOME/vanadium  # Or any other directory of your choosing
   go get v.io/x/ref/...
   ```

At this point, you should be ready to develop your own Vanadium binaries and
build them using `go build` or `go install`.

# Cross-compiling from your laptop/desktop

Developing and building on the Pi is all great, but if you have a
laptop/desktop that you prefer to use instead - which has all your editor
customizations, screen size, keyboard you love etc., then you can also build
binaries for the [RaspberryPi] on it.

The Vanadium codebase includes some C-code, and thus you need a cross-compiler
that can compile C-code into a binary suitable for the ARM architecture. If you
performed the setup steps described in the [contribution guidelines], you can
use the [jiri] tool to install the required cross-compiler.

```
# Install the cross-compiler
jiri profile-v23 install --target=arm-linux v23:base

# Compiling a binary for the Pi
jiri go -target=arm-linux install v.io/x/ref/cmd/principal
```

This will place the binary under
`$JIRI_ROOT/release/go/bin/linux_arm/principal`.  You can then copy this binary
using `scp` or some other mechanism to your Pi.

# Using the GPIO ports

Your RaspberryPi projects might involve some circuit manipulation using the
available GPIO ports. [Search the web][gpio-libs] to settle on
which of a variety of Go libraries to manipulate the GPIO ports you'd like to
play with.

[RaspberryPi]: https://www.raspberrypi.org/
[Raspian]: https://www.raspberrypi.org/documentation/installation/installing-images/README.md
[Go]: https://golang.org
[jiri]: /tools/jiri.html
[contribution guidelines]: /community/contributing.html
[rpi-documentation]: https://www.raspberrypi.org/documentation/
[gpio-libs]: https://www.google.com/search?q=golang+gpio+raspberry+pi
