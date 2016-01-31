= yaml =
title: Raspberry Pi
author: ashankar@
sort: 3
toc: true
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

1. Need the [Go] compiler. Unfortunately, there are no official Go compiler distributions for
   the processor architecture of the Pis. You could compile it from source, but might prefer
   [Dave Cheney's unofficial distribution][go-arm].
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
binaries for the [RaspberryPi] on it. The catch is that your laptop/desktop
must be running Linux.

Once Go 1.5 is released and we remove a few vestigal C code, these instructions
should become much less onerous.  Furthermore, you will be able to build
binaries for your Pi running Linux on your laptop/desktop running either Linux
or Mac OS X, courtesy [significant improvements][go1.5xcompile] in the Go
compiler's support for cross-compilation.

Till then:
1. Install the [jiri] tool as per the [contribution guidelines].
2. Setup the cross-compiler using `jiri v23-profile install arm`

Let's say you're building a binary (such as the `principal` command-line tool)
for the machine you're developing on, you'd likely do something like:
```
jiri go install v.io/x/ref/cmd/principal
```

To build it for the Pi, use:
```
JIRI_PROFILE=arm jiri go install v.io/x/ref/cmd/principal
```

This will place the binary under
`$JIRI_ROOT/release/go/bin/linux_arm/principal`.  You can then copy this binary
using `scp` or some other mechanism to your Pi.

# Using the GPIO ports

Your RaspberryPi projects might involve some circuit manipulation using the
available GPIO ports. [Search the
web][gpio-libs] to settle on
which of a variety of Go libraries to manipulate the GPIO ports you'd like to
play with.

[RaspberryPi]: https://www.raspberrypi.org/
[Raspian]: https://www.raspberrypi.org/documentation/installation/installing-images/README.md
[Go]: https://golang.org
[go1.5xcompile]: http://dave.cheney.net/2015/03/03/cross-compilation-just-got-a-whole-lot-better-in-go-1-5
[installation instructions]: /installation/index.html
[jiri]: /tools/jiri.html
[contribution guidelines]: /community/contributing.html
[rpi-documentation]: https://www.raspberrypi.org/documentation/
[go-arm]: http://dave.cheney.net/unofficial-arm-tarballs
[gpio-libs]: https://www.google.com/search?q=golang+gpio+raspberry+pi
