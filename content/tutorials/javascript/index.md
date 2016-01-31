= yaml =
title: Overview
layout: tutorial
sort: 1
toc: false
= yaml =

Vanadium can be used to build secure, distributed applications for the web.
Servers and clients can be written in JavaScript to run under
a [browser] or [Node.js] and communicate via RPC.

By using the [Vanadium Definition Language][vdl] (VDL),
Vanadium apps written in JavaScript can also communicate
with Vanadium servers and clients written in other languages.

Chrome (desktop) is currently required for browser applications,
but this will change in the future.

The following tutorials build on the [Client/Server Basics tutorial] and demonstrate
Vanadium's JavaScript API. While the tutorials are targeted toward
running in the browser, the code can be adapted to run in a [Node.js] environment.

* [Hello Peer][hellopeer]

  _Wherein_ Vanadium says hello in a peer-to-peer manner.

* [Fortune in JS][fortune]

  _Wherein_ you build a fortune teller service and a client to talk to it.


[vdl]: /glossary.html#vanadium-definition-language-vdl-
[Node.js]: https://nodejs.org/
[browser]: https://www.google.com/chrome/
[hellopeer]: /tutorials/javascript/hellopeer.html
[fortune]: /tutorials/javascript/fortune.html
[Client/Server Basics tutorial]: /tutorials/basics.html
