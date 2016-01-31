= yaml =
title: Syncbase
sort: 5
toc: true
= yaml =

## Overview

Syncbase is a storage system for developers that makes it easy to synchronize
app data between devices. It works even when devices are not connected to the
Internet.

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

## Background

There are many storage systems that synchronize data between mobile devices, but
most such systems are cloud-centric rather than peer-to-peer, and the few that
are peer-to-peer typically focus on files rather than structured storage. In
addition, very few systems have the fine-grained access control or powerful,
configurable conflict resolution we want. In summary, we're trying to solve a
bunch of problems simultaneously whereas those other systems each solve a subset
of those problems.

## Data Model

Syncbase holds blob data and two types of structured data. The data is organized
by the following hierarchy:
- App: Each app has its own namespace to prevent conflicts. An app can contain
  multiple databases but will usually contain only one.
- Database: The system is designed for multiple types of database. The NoSQL
  database is currently implemented, and we are starting to design the SQL
  database. Both types support blobs and fine-grained synchronization. Queries
  and batches, which are similar to transactions, are limited to the scope of a
  single database.
  - **NoSQL**: Tables in a NoSQL database map a key to a structured value. The
    value's type is vdl.Any, and reflection allows features like queries to
    access the fields within the struct (if it is a struct). The keys are always
    strings and kept separate from values (unlike MongoDB). The keys are ordered
    to support efficient scan of related entries. Queries are specified with a
    SQL style language, and functionality is currently limited to filtering the
    values returned by the ordered scan. Tables are heterogeneous to allow for
    related data to be denormalized. If the developer wishes for homogeneous
    tables, it is up to the developer to enforce that.
  - **SQL**: (Not yet implemented, and may be folded into NoSQL by supporting
    optional schemas, secondary indexes, and richer queries.) A SQL table
    implements the SQL 92 standard as much as possible while still supporting
    blobs and synchronization. We recognize that there are certain apps that
    stretch the limits of the NoSQL data model.

### Blobs

Both SQL and NoSQL databases have strong support for blobs. Blobs support a
streaming upload/download API rather than the all-at-once operations of the
structured data. Syncbase understands references to blobs in the structured
data, making it possible to implement automatic caching and garbage collection
of the blobs. Blob references implicitly grant access to blobs in a manner
similar to a capability (see [blob references](#references)).

### Batches

A batch is a group of read and write operations that are logically related. When
an app uses Syncbase without synchronization, a batch is equivalent to an ACID
transaction.

- Atomic: All writes that are part of the batch are committed together.
- Consistent: Any batches started in the future necessarily see the effects of
  batches committed in the past.
- Isolated: The concurrent execution of batches results in a state that would be
  equivalent to the batches executing serially in some order.
- Durable: Once a batch has been committed, it will remain committed in the face
  of power loss or crashes.

When an app uses Syncbase with synchronization, a batch no longer provides ACID
semantics. Syncbase is a loosely coupled, decentralized, distributed storage
system, so the guarantees of batches are appropriate for that environment.

- Atomic: All read and write operations that are part of the batch are
  synchronized as an atomic unit. However, a [conflict
  resolver](#resolving-conflicts) may merge two batches by taking part of one
  batch and another part of the other batch.
- Consistent: Consistency is impossible to provide when devices are allowed to
  work offline. A user could perform an operation on one device and then attempt
  to perform an operation on a second device before the two devices have synced
  with each other.
- Isolated: Conflict resolvers could violate isolation guarantees by improperly
  merging two batches.
- Durable: While batches are durable in the common case, there are two
  exceptions:
  - The batch is committed on a device while partitioned from other devices. The
    device never syncs with other devices (e.g. dropped in the river).
  - A poorly written conflict resolver erroneously discards the conflicting
    batch rather than merging it.

While the edge cases prevent us from claiming ACID semantics, we believe that
the behavior above strikes a good balance between implementable semantics and
useful behavior for the developer and user.

Batches are not limited to the data within a syncgroup (see below). If a batch
contains data from multiple syncgroups, peers will receive only the parts of the
batch for which they are a member.

### Access Control

Syncbase enables collaboration between multiple users, so it is important for it
to have fine grained access control. Syncbase uses the [Vanadium security model]
for identification and authentication. The mechanisms for authorization vary by
database type.

#### NoSQL ACLs

Developers specify ACLs with a key prefix. If there are multiple prefixes for a
row, the longest prefix wins. This behavior makes it easy to set an ACL on
related data and have new data automatically inherit the right ACL if possible.

We expect developers to give a common key prefix to related data. For example, a
TODO list might have a table like:

    <list uuid>                -> List
    <list uuid>/entries/<uuid> -> Entry
    <list uuid>/entries/<uuid> -> Entry

All entries in the list have a common prefix, making it easy to find all of the
entries in the list. Because this list is fully collaborative, the developer
would set a simple ACL like:

    <list uuid> -> {<owner>: Read, Write, Admin; <friends>: Read, Write}

All entries in the list would inherit this ACL. We expect that most apps will
use a single ACL for a group of related data, so we optimized for this case.

There are also apps that will require finer-grained ACLs. For example, a blog
might have a table like:

    <post uuid>                                 -> Post
    <post uuid>/comments/<uuid>                 -> Comment
    <post uuid>/comments/<uuid>/comments/<uuid> -> Comment
    <post uuid>/comments/<uuid>                 -> Comment
    <post uuid>/comments/<uuid>                 -> Comment

All comments on the Post have a key with a prefix of the Post's uuid. This makes
it efficient to find all of the comments for the post. Comments on comments (row
3) are similarly nested. The developer would set ACLs like:

    <post uuid>                 -> {<author>: Read, Write, Admin; <friends>: Read}
    <post uuid>/comments/       -> {<author>: Read, Write, Admin; <friends>: Read, Insert}
    <post uuid>/comments/<uuid> -> {<friend>: Read, Write, Admin; <friends>: Read}
### SQL ACLs

*Lots TBD here. We're thinking that the developer would use a query to specify
the ACL. This would mean that the ACL is dependent on the properties of the data
(e.g. salesperson can see all customer data where Location = "CA").*

### Blob ACLs

See [blob references](#references).

## Synchronization

The sync protocol is peer-to-peer whereas most other sync systems (e.g.
Firebase) require a centralized server. We believe that despite internet
connectivity becoming more and more prevalent, there will always be times when
an internet connection is not available. You should be able to sync with your
peer, with very low latency, when you are physically close. For example, you
shouldn't need an internet connection to set the temperature on your thermostat.
Syncbase uses the cloud as another, very durable peer, but the cloud is not
required for any two peers to interact. Because the cloud is not in the critical
path for synchronization, apps can use Syncbase as for asynchronous, relatively
low latency communication.

Peer-to-peer sync introduces problems not present in client-server sync:
- Sub-groups of devices can collaborate independently, leading to substantial
  data conflicts
- If all peers are equal, hiding data from a subset of those peers is tricky.
  For example, User1, User2, and User3 sync with each other. User1 and User2
  have access to A, B, and C. User3 can access only C. If User1 atomically
  modifies A and C, how does User3 propagate that change to User2 without seeing
  the contents of A?
- Malicious peers can perform man-in-the-middle attacks. The system should help
  prevent them.

We define a _syncgroup_ as a set of data that is synchronized within a set of
devices. The following sections describe which data and which devices make up a
syncgroup.

### Which data?

#### NoSQL

A database can have multiple syncgroups each specified by a set of (table, row
prefix) pairs. We expect apps to typically have a single database and splice in
data from various syncgroups. For example, a Todo app could use the NoSQL
database with rows like:

    <list1 uuid>                -> List
    <list1 uuid>/entries/<uuid> -> Entry
    <list1 uuid>/entries/<uuid> -> Entry
    <list2 uuid>                -> List
    <list2 uuid>/entries/<uuid> -> Entry
    <list2 uuid>/entries/<uuid> -> Entry

The app could then create two syncgroups: one with the prefix "<list1 uuid>" and
another with the prefix "<list2 uuid>". Another user's "<list3 uuid>" syncgroup
could be added directly to this database. It is important that the developer use
UUIDs to avoid conflicts. However, the system does not enforce that the
developer use UUIDs because there are times when the developer might actually
want conflicts.

Syncgroups may be nested within each other. For example, if the Todo app puts
lists in folders, it can sync a folder one way and sync the lists within it in
another way. Note that the keys are fully copied regardless of the syncgroup; it
is not possible to "mount" a syncgroup with a different key prefix.

#### SQL

*The SQL database similarly represents a syncgroup with a query. Lots TBD.*

#### ACLs

The sync protocol respects the ACLs on the data. That means that if a peer is
not in the ACL for a row, that row is not sent to that peer. This makes conflict
resolution more complicated (e.g. a batch might contain some data that is
visible to the device and some data that is not).

If a peer has read-only access to a row, it can still propagate changes from
peers that do have write access to that row. This opens up the possibility of
this read-only peer performing a man-in-the-middle attack. Syncbase provides the
ability to digitally sign mutations to these mixed-privilege rows, and the
receivers automatically verify the signatures. Public key encryption is
computationally expensive, so it is up to the developer to determine which rows
require signatures.

#### Example Apps

We examined 10 apps in detail to understand what granularity of access control
and syncing was appropriate. For some apps like a news reader or a brokerage,
everything is single user, so syncing all of the data in the local database is
appropriate. For apps like turn-based games or Nest, there are islands of data
(e.g. one instance of a game is totally separate from another, one house is
totally separate from another), so grouping the data into syncgroups is easy.
The remaining apps were more complicated.

For productivity apps like Todos or Docs, it might make sense to have folders
and subfolders. The user might want to share a root folder, a subfolder, or
maybe even a single document nested deep in the folder structure. Assuming that
the keys map to the folder structure, what happens when another user "mounts"
that folder or document into his own database? Do the keys stay the same or are
they rewritten so the folder or document is at the top level of the database.
For example, if "folder2" below is synced, does the peer see "folder1/folder2"
or just "folder2"?

    folder1
    folder1/doc1
    folder1/folder2
    folder1/folder2/doc2

We decided that the keys would be fully copied between the peers in the
syncgroup (i.e. "folder1/folder2").

We recognize that these hierarchical folders are not a perfect fit for the NoSQL
data model. Our goal is that the SQL database handles this much better.

### Which devices?

Our primary goal is to make it simple to sync data between a single user's
devices. Our secondary goal is to synchronize data between multiple users'
devices. For both of these, we use the ACL Group Server to represent this list
of devices.

### Resolving Conflicts

The majority of apps would benefit greatly from simple, automatic conflict
resolution policies (e.g. last-one-wins, min, max), some apps would benefit from
more sophisticated operational transforms (OT) (e.g. lists, strings), while a
small number of apps have policies best encoded in the app itself. We should
strive to make the simple, automatic conflict resolution policies as convenient
as possible even if it comes at the expense of making other conflict resolution
policies more difficult to use. OT policies or datatypes such as
CollaborativeString and CollaborativeMap supported by the [Google Realtime
API](https://developers.google.com/drive/realtime/reference/) are helpful but
not sufficient for all apps. Finally, some apps have such unique policies that
attempting to encode them in some "conflict resolution language" would be
counter-productive. For these apps, we provide them with an API that is at a low
enough level that they can do whatever they want in application code. We believe
that API should provide access to a tuple of (local version, peer version,
common ancestor version).

### Pluggable Sync

Syncbase provides an escape hatch for apps that do not fit entirely into the
storage and synchronization model. For example, some apps have existing,
canonical data in Oracle or Megastore (e.g. Google Calendar). Other apps need to
broadcast identical data to many users (e.g. DVR program guide). For these
reasons, Syncbase makes it easy to plug custom code into the sync protocol.

*Lots of details TBD at this point. The need for this feature is clear, but we
need to look at the detailed requirements.*

### Blobs

The synchronization policy for blobs is different than the policy for structured
data. All structured data in the syncgroup is synchronized to all devices in the
syncgroup. However, a single device might not have enough storage space to hold
all blobs in the syncgroup, or copying a blob might be undesirable over a cell
network. As a result, there might be a reference from structured storage to a
blob that is not present on the local device. Apps need to function even when
some blobs are not present.

#### Versions

A blob is immutable once created, so blobs are not versioned. The blob API
allows the app to efficiently create a new blob based on the content of another
blob (e.g. edit the ID3 tags of an MP3). The new blob must be referenced by an
entry in the structured data so that other devices learn of the new blob.

#### References

The structured data contains references to the blobs by storing a BlobRef in a
field. There is an API for apps to specify per-device caching policies so that
not all blobs need to be on all devices. It is the responsibility of Syncbase to
watch for BlobRefs in the structured storage and cache the right blobs on each
device.

The ACL protecting the BlobRef in structured storage acts as an implicit ACL for
the blob itself. The ACL protects the BlobRef, but once the BlobRef is
accessible, it acts as a capability. Any app instance possessing the BlobRef can
access the blob. A BlobRef can be copied into another row, table, database, or
even app. However, the BlobRef only works on the Syncbase from which it came
(i.e. sending a BlobRef over RPC to another device is not useful).

#### Durability

Syncbase ensures that not all peers will simultaneously evict a blob because
that would result in data loss. The sync protocol keeps track of which peers
have which blobs, and certain peers can be marked as "durable". For example, a
Cloud peer could have effectively unlimited storage space and never need to
evict blobs. When an ordinary peer sees that the blob has made it to a durable
peer, the ordinary peer is free to evict the blob. Note that it is possible for
multiple peers to be durable.

To permanently delete a blob, all references to the blob must be deleted. The
durable peer holding the blob can detect when the other peers have deleted their
references. Once a peer has deleted all references, it can not fabricate a new
reference to the blob. The durable peer can then look at the history of the
structured data to detect when all peers have deleted their references and the
blob itself can be safely deleted.

## Data Encryption

*It is important that the data be encrypted at rest. We should also figure out
if we can have peers that replicate the data but are not allowed to see the
contents. Lots of details TBD.*

## Multiple Implementations

Syncbase needs to work on a variety of devices and configurations. Not only does
it need to work well on phones, tablets, desktops, and other networked devices,
app developers also need a multi-tenant deployment they can provide to their
users for durability and ease of use. We plan the following implementations:

### Mobile

We need an implementation that works well on mobile devices. It should be aware
of performance constraints of mobile flash devices. It needs to be aware of
battery and network usage too. This implementation does not need to scale to
huge sizes nor to high throughput.

### Cloud

This version of Syncbase acts as a cloud peer.

- Completely open source. It is important to the success of the project that
  developers are not locked in to a Google service. They need an escape hatch.
- It may or may not have an instance of the app available to resolve conflicts.
- It needs to function as a multi-tenant service that app developers can run for
  their users.
- It should be simple for an app developer or advanced user to deploy (e.g. VM
  image with everything required).
- The first version does not need to scale beyond a single machine. This
  implementation would probably use MySQL as the underlying storage layer and
  could likely handle tens of thousands of users. Further scale would be up to
  the developer or open source community.

One idea that we need to explore further is for the cloud peer to be sync-only.
It would not support Put/Get/Delete/Scan/Query. By removing that functionality,
we could potentially increase scalability and simplify deployment.

[Vanadium security model]: security.html
