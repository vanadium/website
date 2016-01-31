= yaml =
title: Overview
layout: tutorial
sort: 30
toc: false
= yaml =

_Naming_, like security, is central to Vanadium.

Naming is Vanadium's term for service identification and discovery.

The following tutorials build from the [basics tutorial] to
demonstrate code and pre-built tools that implement and benefit from
Vanadium naming.

* [The Mount Table]<br>
  _Wherein_ you use the basic tools of service discovery.

* [Namespaces]<br>
  _Wherein_ you manipulate multiple mount tables to create a rich namespace.

* [The Suffix - Part I]<br>
  _Wherein_ for the first time you build a server with multiple services
  and use the server's namespace to address them (an advanced tutorial).

* [The Suffix - Part II]<br>
  _Wherein_ you add fine-grained security to control access to your
  multiple services (an advanced tutorial).

* [Globber]<br>
  _Wherein_ you use the Globber interface to create your own server
  namespace (an advanced tutorial).

The [naming concepts document] provides a high-level discussion
of naming that complements these tutorials.

[The mount table]: /tutorials/naming/mount-table.html
[Namespaces]: /tutorials/naming/namespace.html
[The suffix - Part I]: /tutorials/naming/suffix-part1.html
[The suffix - Part II]: /tutorials/naming/suffix-part2.html
[Globber]: /tutorials/naming/globber.html
[naming concepts document]: /concepts/naming.html
[basics tutorial]: /tutorials/basics.html
