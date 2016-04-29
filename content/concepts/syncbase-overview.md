= yaml =
title: Syncbase
sort: 5
toc: true
= yaml =

Syncbase is a storage system for developers that makes it easy to synchronize
app data between devices. It works even when devices are not connected to the
Internet.

(The video below describes an app built for web browsers.  Syncbase is currently
focused on Android and iOS, and we have removed browser support.  The concepts
in the video are still valid, however.)

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
  - Structured databases are easy to use and support transactions and notifications
  - Blob caching policies work well on resource-limited devices
- Powerful management tools
  - Leverages the Vanadium namespace and security system
  - Open source reference implementation of Syncbase for developers who want
    tight control over the data

The initial version of Syncbase is ready for testing and evaluation by early
adopters.

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

# Data Model

Syncbase holds blob data and structured data. The data is organized
by the following hierarchy:

- Database: An app is preconfigured to have a single database which may contain
  any number of Collections.
- Collection: A collection is an ordered set of key-value pairs (rows), where
  keys are strings and values are structured types.
  Collections are the unit of access control and can be grouped together
  for synchronization.
- Row: Each row contains a single value, and the values in the rows of a
  Collection are heterogeneous.  Therefore, developers should denormalize
  their data, grouping related data by giving those rows a common key prefix.

## Blobs

Syncbase has strong support for blobs. Blobs support a
streaming upload/download API rather than the all-at-once operations of the
structured data. Syncbase understands references to blobs in the structured
data, making it possible to implement automatic caching and garbage collection
of the blobs. Blob references implicitly grant access to blobs in a manner
similar to a capability (see [blob references](#references)).

## Batches

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

Batches are not limited to the data within a Collection. If a batch contains
data from multiple Collections, peers will receive only the parts of the batch
they are allowed to see.

## Access Control

Syncbase enables collaboration between multiple users, so access control is an
important feature.  Syncbase uses the [Vanadium security model]
for identification and authentication.

Each Collection in a database has its own ACL specifying who can access and modify
the rows in that Collection.  This ACL is synced along with the data itself.
'Admin' access grants the client permission to change the ACL.  'Write' access
allows the client to insert and update rows in the Collection.  'Read'
represents a read-only privilege.  These ACLs are enforced by the local
Syncbase as well as by peer Syncbases during the sync protocol.

Using a TODO list app as an example, each list would live in its own Collection.
This allows the user to share a grocery list with a spouse and a party planning
list with a friend.  Syncbase synchronizes the two lists independently, yet
the two lists show up in the same database, making it easy to display them in
an "all my lists" UI.

## Blob ACLs

See [blob references](#references).

# Synchronization

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
- Malicious peers can perform man-in-the-middle attacks. The system should help
  prevent them.

We define a _syncgroup_ as a list of Collections that are synchronized within
a set of devices. There can be multiple syncgroups for a single Collection,
making it possible for a single device to bridge between otherwise disjoint
groups of devices.

## Arranging data for sync

Continuing with our TODO list example, there would be a Collection for each
list.  There might also be a Collection to store the user's preferences.

    Collection for preferences
    preferences    -> Preferences
    last-viewed    -> String      // The ID of the last viewed TODO list.

    Collection for list1
    metadata       -> List
    entries/<uuid> -> Entry
    entries/<uuid> -> Entry

    Collection for list2
    metadata       -> List
    entries/<uuid> -> Entry
    entries/<uuid> -> Entry

The app could then create three syncgroups:

* Preferences Collection: Synced across the user's devices.  Private to that user.
* list1 Collection: Synced across the user's devices as well as Alice and Bob's
  devices.
* list2 Collection: Synced across the user's devices as well as Alice and Carol's
  devices.

Collections created by all users live in the same namespace.  To avoid
collisions, the system automatically prepends the user's identity (blessing)
to the Collection ID.  The developer still needs to think about collisions,
however.  The user might use one device while offline and then switch to
another device while still offline. When those two devices sync with each
other, should the Collections merge or stay separate?  If the developer wants
them to stay separate, the Collection IDs should include a UUID.  If the
developer wants them to merge, they should use a predictable name (e.g.
"preferences").

It is not possible to sync a subset of a Collection differently than the whole
Collection.  The typical solution to this problem is to pull that subset of data
into its own Collection and leave a reference/pointer in the original Collection.

## ACLs

The sync protocol respects the ACLs on the data. If a peer has read-only
access to a row, it can still propagate changes from peers that do have write
access to that row. To prevent this read-only peer from performing a man-in-
the-middle attack, Syncbase will sign the mutations on behalf of the writer.
The receivers automatically verify the signatures.

## Example Apps

We [examined 15+ apps in detail](/designdocs/syncbase-examples.html)
to understand what granularity of access control and syncing was appropriate.
For some apps like a news reader or a brokerage, everything is single user, so
syncing all of the data in the local database is appropriate. For apps like
turn-based games or Nest, there are islands of data (e.g. one instance of a
game is totally separate from another, one house is totally separate from
another), so grouping the data into syncgroups is easy. The remaining apps
were more complicated.

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

We explored this topic in great detail, building a FileManager app in the process.
We concluded that if a developer wishes to share a subfolder differently than the
parent folder, the developer should move the subfolder to its own Collection and
leave a reference in the original Collection.

## Which devices?

Our primary goal is to make it simple to sync data between a single user's
devices. Our secondary goal is to synchronize data between multiple users'
devices. For both of these, we use the ACL Group Server to represent this list
of devices.

## Resolving Conflicts

The majority of apps would benefit greatly from simple, automatic conflict
resolution policies (e.g. last-one-wins, min, max), some apps would benefit
from more sophisticated operational transforms (OT) (e.g. lists, strings) or
Conflict-free Replicated Data Types (CRDT), while a small number of apps have
policies best encoded in the app itself. We should strive to make the simple,
automatic conflict resolution policies as convenient as possible even if it
comes at the expense of making other conflict resolution policies more
difficult to use. OT policies or datatypes such as CollaborativeString and
CollaborativeMap supported by the
[Google Realtime API](https://developers.google.com/drive/realtime/reference/)
are helpful but not sufficient for all apps. Finally, some apps have such unique
policies that attempting to encode them in some "conflict resolution language" would be
counter-productive. For these apps, we will provide them with an API that is at a
low enough level that they can do whatever they want in application code. We
believe that API should provide access to a tuple of (local version, peer
version, common ancestor version).  This information is stored in Syncbase,
but we have not yet exposed this API to applications.

## Pluggable Sync

Syncbase provides an escape hatch for apps that do not fit entirely into the
storage and synchronization model. For example, some apps have existing,
canonical data in an Oracle or MySQL database. Other apps need to
broadcast identical data to many users (e.g. DVR program guide). For these
reasons, Syncbase should make it easy to plug custom code into the sync protocol.

*Lots of details TBD at this point. The need for this feature is clear, but we
need to look at the detailed requirements.*

## Blobs

The synchronization policy for blobs is different than the policy for structured
data. All structured data in the syncgroup is synchronized to all devices in the
syncgroup. However, a single device might not have enough storage space to hold
all blobs in the syncgroup, or copying a blob might be undesirable over a cell
network. As a result, there might be a reference from structured storage to a
blob that is not present on the local device. Apps need to function even when
some blobs are not present.

### Versions

A blob is immutable once created, so blobs are not versioned. The blob API
allows the app to efficiently create a new blob based on the content of another
blob (e.g. edit the ID3 tags of an MP3). The new blob must be referenced by an
entry in the structured data so that other devices learn of the new blob.

### References

The structured data contains references to the blobs by storing a BlobRef in a
field. There is an API for apps to specify per-device caching policies so that
not all blobs need to be on all devices. It is the responsibility of Syncbase to
watch for BlobRefs in the structured storage and cache the right blobs on each
device.

The ACL protecting the BlobRef in structured storage acts as an implicit ACL
for the blob itself. The ACL protects the BlobRef, but once the BlobRef is
accessible, it acts as a capability. Any app instance possessing the BlobRef
can access the blob. A BlobRef can be copied into another row, collection, or
database. However, the BlobRef only works on the Syncbase from which it came
(i.e. sending a BlobRef over RPC to another device is not useful).

### Durability

Syncbase ensures that not all peers will simultaneously evict a blob because
that would result in data loss. The sync protocol keeps track of which peers
have which blobs, and certain peers can be marked as more durable than others.
For example, a Cloud peer could have effectively unlimited storage space and
never need to evict blobs. When an ordinary peer sees that the blob has made
it to a durable peer, the ordinary peer is free to evict the blob. Note that
it is possible for multiple peers to be durable.

To permanently delete a blob, all references to the blob must be deleted. The
durable peer holding the blob can detect when the other peers have deleted their
references. Once a peer has deleted all references, it can not fabricate a new
reference to the blob. The durable peer can then look at the history of the
structured data to detect when all peers have deleted their references and the
blob itself can be safely deleted.

# Data Encryption

*It is important that the data be encrypted at rest. We should also figure out
if we can have peers that replicate the data but are not allowed to see the
contents. Lots of details TBD.*

# Multiple Implementations

Syncbase needs to work on a variety of devices and configurations. Not only does
it need to work well on phones, tablets, desktops, and other networked devices,
app developers also need a multi-tenant deployment they can provide to their
users for durability and ease of use. We offer the following implementations:

## Mobile

There is an implementation that works well on mobile devices. It is aware
of performance constraints of mobile flash devices. It is also aware of
battery and network usage. This implementation does not need to scale to
huge sizes nor to high throughput.

## Cloud

This version of Syncbase acts as a cloud peer.

- Completely open source. It is important to the success of the project that
  developers are not locked in to a Google service. They need an escape hatch.
- It may or may not have an instance of the app available to resolve conflicts.
- It needs to function as a multi-tenant service that app developers can run for
  their users.
- It is simple for an app developer or advanced user to deploy (e.g. VM
  image with everything required).
- The first version does not scale beyond a single machine. This
  implementation is mostly the same as the mobile implementation and is suitable
  for prototyping.  A subsequent version would probably use MySQL as the
  underlying storage layer and could likely handle tens of thousands of users.
  Further scale would be up to the developer or open source community.

One idea that we need to explore further is for the cloud peer to be sync-only.
It would not support Put/Get/Delete/Scan. By removing that functionality,
we could potentially increase scalability and simplify deployment.

[Vanadium security model]: /concepts/security.html
