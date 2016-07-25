= yaml =
title: Overview
layout: tutorial
sort: 30
toc: false
= yaml =

Syncbase provides a database that supports peer-to-peer synchronization built on
top of Vanadium. It works even when devices are not connected to the Internet.

In the following tutorials, we will modify the code from the [basics tutorial]
so it runs over Syncbase. This will allow us to synchronize our set of fortunes
across multiple devices.

* [Persisting to Local Storage]<br> _Wherein_ fortunes are stored in a local
  Syncbase.

* [Exchanging Data]<br> _Wherein_ devices exchange their local data with each
  other.

These tutorials use a low level Syncbase API. The [Syncbase tutorial]
complements this tutorial and uses a higher level API for mobile development
which facilitates many of the patterns illustrated here.

[basics tutorial]: /tutorials/basics.html
[Syncbase tutorial]: /syncbase/tutorial/introduction.html
[Persisting to Local Storage]: /tutorials/syncbase/localPersist.html
[Exchanging Data]: /tutorials/syncbase/sync.html

