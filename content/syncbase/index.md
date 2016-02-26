= yaml =
title: Syncbase
layout: syncbase
toc: true
= yaml =

Syncbase is a storage system for developers that makes it easy to synchronize
app data between devices. It works even when devices are not connected to the
Internet.

<iframe width="560" height="315" src="https://www.youtube.com/embed/2cHzd8pBYmU" frameborder="0" allowfullscreen></iframe>

# Why use Syncbase?

- Synchronization between one user's devices is trivial to configure; multiple
  users can synchronize specific data too
  - Low latency synchronization enables many apps to use storage for
    asynchronous communication
- Internet connection not required
  - Local storage still works when not connected to the internet
  - Synchronization protocol is peer-to-peer and works just as well over local
    WiFi or Bluetooth as the internet
- Conflict resolution system merges data when devices have been working offline
- Unified storage model handles both structured data and blobs
  - Structured databases are easy to use and queryable
  - Blob caching policies work well on resource-limited devices
- Powerful management tools
  - Leverages the Vanadium namespace and security system
  - Open source reference implementation of Syncbase for developers who want
    tight control over the data

The initial version of Syncbase is ready for testing and evaluation by early
adopters - it is suitable for prototyping, but not for production applications.

This document presents an overview of the system. It is very light on
implementation details. Subsequent docs will contain those details.

# Background

There are many storage systems that synchronize data between mobile devices, but
most such systems are cloud-centric rather than peer-to-peer, and the few that
are peer-to-peer typically focus on files rather than structured storage. In
addition, very few systems have the fine-grained access control or powerful,
configurable conflict resolution we want. In summary, we're trying to solve a
bunch of problems simultaneously whereas those other systems each solve a subset
of those problems.
