= yaml =
title: Roadmap
toc: true
= yaml =


1. **Syncbase API usability**

  We have recently conducted API usability tests
and are working on a new high-level API to help developers get
started quickly with Syncbase.

1. **Website, docs & sample app improvements**
  * My First App: Android & iOS
  * todo tutorial (and sample app with new APIs)
  * update syncslides to new API
  * tutorial that doesn't require syncbase cloud

1. **Blobs**

  Blobs are already implemented in Go and sync across Syncbase instances,
  and there exists low-level RPC support, also in Go; however, there is not yet
  a high level API in Swift or Java to access this functionality on an iOS
  or Android device.

  Syncbase was designed with strong support for blobs. Blobs will support a
  streaming upload/download API rather than the all-at-once operations of the
  structured data. Syncbase understands references to blobs in the
  structured data, making it possible to implement automatic caching and garbage
  collection of the blobs.

  Blob references implicitly grant access to blobs in a manner similar to a
  [capability](https://en.wikipedia.org/wiki/Capability-based_security). Blob
  references can be stored as values in the key-value store. There
  is a planned API for apps to specify per-device caching policies so that not
  all blobs need to be in all devices. Syncbase will watch for blob references
  in the structured storage and cache the right blobs on each device.

1. **Syncbase query support**

  We are considering support for querying values in structured data. For
example, one could find all the `MyPojo` objects that have the value `bar > 10`.
1. **Syncbase collection schema**

  We are considering support for Syncbase schema. To support stronger data
integrity, collections could be tied to a data schema, and Syncbase would
ensure all written values match that schema or write will fail.

1. **and more...**

  We have lots of ideas, but we're excited to discover what applications find
  Vanadium and Syncbase most useful.  Please join our
  [mailing list](/community/mailing-lists.html) and let us know what you are
  building (or thinking about building).
