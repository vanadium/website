= yaml =
title: Syncbase for Android
layout: syncbase
toc: false
= yaml =

Syncbase is a storage system for developers that makes it easy to synchronize
app data between devices. It works even when devices are not connected to the
Internet. Syncbase runs on both Android and iOS.

<iframe width="560" height="315" src="https://www.youtube.com/embed/2cHzd8pBYmU" frameborder="0" allowfullscreen></iframe>

<figcaption>Syncbase's easy-to-use API and peer-to-peer synchronization make
developing offline-first mobile apps a breeze.</figcaption>

# Why use Syncbase?

<div class="intro-detail intro-detail-offline">
<p>
**Offline-first and peer-to-peer**<br>
Syncbase provides local storage that opportunistically syncs data behind the
scenes with very low latency. Then built-in conflict resolvers merge data
seamlessly when devices have been working offline.
<br>
There is no cloud instance or internet required for data synchronization to work.
Synchronization protocol is peer-to-peer and works just as well over local WiFi
or Bluetooth as the internet. Of course, optionally adding a cloud peer can help
with data backup and improved data availability.
</p>
</div>

<div class="intro-detail intro-detail-codebase">
<p>
**Easy to use**<br>
Syncbase includes a high-level API that's intuitive and easy-to-use.
The data model is simple to understand and based on collections of
key-value pairs.<br>
Synchronization between one user's devices works out of the box and sharing
data with other users is trivial.
</p>
</div>

<div class="intro-detail intro-detail-security">
<p>
**Secure**<br>
Syncbase is secure by default. All data is only accessible by the creator unless
shared explicitly with others using Syncbase's fine-grained access control
feature.<br>
When synchronizing with peers, all communication is encrypted end-to-end on the
wire.
</p>
</div>

# Background

There are many storage systems that synchronize data between mobile devices, but
most such systems are cloud-centric rather than peer-to-peer, and the few that
are peer-to-peer typically focus on files rather than structured storage. In
addition, very few systems have the fine-grained access control or powerful,
configurable conflict resolution we want. In summary, we're trying to solve a
bunch of problems simultaneously whereas those other systems each solve a subset
of those problems.

# Ready to get started?

The initial version of Syncbase is ready for testing and evaluation by early
adopters - it is suitable for prototyping, but not for production applications.

<a href="/syncbase/quickstart.html" class="button-passive">
Get started quickly
</a>