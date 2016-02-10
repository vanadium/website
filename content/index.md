= yaml =
title:
fullTitle: Vanadium
= yaml =

Vanadium is an [open-source](https://github.com/vanadium) framework designed to
make it much easier to develop secure, distributed applications that can run
anywhere. It provides:
+ a complete security model, based on public-key cryptography, that supports
  fine-grained permissions and delegation. The combination of traditional ACLs
  and "blessings with caveats" supports a broad set of practical requirements.
+ symmetrically authenticated and encrypted RPC, with support for bi-directional
  messaging, streaming and proxying, that works on a variety of network
  protocols, including TCP and Bluetooth. The result is a secure communications
  infrastructure that can be used for large-scale datacenter applications as
  well as for smaller-scale enterprise and consumer applications, including
  those needing to cross NAT boundaries.
+ a performant, self-describing encoding format, usable from many programming
  languages and platforms (including Go and Java/Android, with more
  on the way).
+ a global naming service that offers the convenience of urls but allows for
  federation and multi-level resolution. The 'programming model' consists of
  nothing more than invoking methods on names, subject to security checks.
+ a discovery API for advertising and scanning for services over a variety of
  protocols, including BLE and mDNS (Bonjour).
+ the ability to use multiple global and/or local identity providers (e.g.
  Google, Facebook, Microsoft Exchange, PAM, etc.). We currently provide an
  OAuth2-based implementation, but others would work just as well.
+ a storage service, Syncbase, that can be run on all devices, large or small,
  and offers synchronized peer-to-peer storage. Syncbase offers:
   - a structured store that can be queried using a SQL-like query language
   - a blob store that synchronizes content across all devices
   - the ability to group data into 'synchronization groups' to control what's
     synced with who
   - fine-grained access control
   - peer-to-peer synchronization with configurable conflict resolution
   - offline operation

The Vanadium APIs are relatively stable and have been subjected to extensive
usability testing. In addition, we've taken care to cleanly separate the APIs
([v.io/v23]) from their implementations.

[v.io/v23]: https://godoc.org/v.io/v23/
