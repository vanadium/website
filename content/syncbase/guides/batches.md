= yaml =
title: Batches
layout: syncbase
sort: 4
toc: true
= yaml =

# Introduction

A batch is a group of read and write operations that are logically related.
When an app uses Syncbase without synchronization, a batch is equivalent to an
ACID transaction.

* *Atomic:* All writes that are part of the batch are committed together.
* *Consistent:* Any batches started in the future necessarily see the effects of
batches committed in the past.
* *Isolated:* The concurrent execution of batches results in a state that would be
equivalent to the batches executing serially in some order.
* *Durable:* Once a batch has been committed, it will remain committed in the face
of power loss or crashes.

When an app uses Syncbase with synchronization, a batch no
longer provides ACID semantics. Syncbase is a loosely coupled, decentralized,
distributed storage system, so the guarantees of batches are appropriate for
that environment.

* *Atomic:* All read and write operations that are part of the batch are
synchronized as an atomic unit. However, a conflict resolver may merge two
batches by taking part of one batch and another part of the other batch.
* *Consistent:* Consistency is impossible to provide when devices are allowed
to work offline. A user could perform an operation on one device and then
attempt to perform an operation on a second device before the two devices have
synced with each other.
* *Isolated:* Conflict resolvers could violate isolation guarantees by
improperly merging two batches.
* *Durable:* While batches are durable in the common case, there are two exceptions:
  * The batch is committed on a device while partitioned from other devices.
The device never syncs with other devices (e.g. dropped in the river).
  * A poorly written conflict resolver erroneously discards the conflicting batch
rather than merging it.

While the edge cases prevent us from claiming ACID semantics, we believe that
the behavior above strikes a good balance between implementable semantics and
useful behavior for the developer and user.

Batches are not limited to the data within a collection. If a batch contains
data from multiple collections, peers will receive only the parts of the batch
they are allowed to see.


# Using Batches

`BatchDatabase` is the entry point to the batch API. `BatchDatabase` is similar to
`Database` except it provides `commit` and `abort` methods and all
operations on collection references obtained from a `BatchDatabase` would be
part of the batch.

### RunInBatch

`RunInBatch` is the recommended way of doing batch operations.
It detects *concurrent batch* errors and handles retries and commit/aborts
automatically.

```Java
db.runInBatch(new Database.BatchOperation() {
  @Override
  public void run(BatchDatabase batchDb) {
    Collection c1 = batchDb.collection("collection1");
    Collection c2 = batchDb.collection("collection2");

    c1.put("myKey", "myValue");
    c2.put("myKey", "myValue");

    // No need to commit. RunInBatch will commit and retry if necessary.
  }
}, new Database.BatchOptions());
```

{{# helpers.warning }}
## Warning

Using collection references previously obtained from `Database` will have no
atomicity effect when used in `RunInBatch`. New collection references must be
obtained from `BatchDatabase`.

**The following code snippet demonstrates the *WRONG* way of using batches.**
{{/ helpers.warning }}

```Java
// WRONG: c1 is NOT part of the batch.
final Collection c1 = db.collection("collection1");
{{# helpers.codedim }}
db.runInBatch(new Database.BatchOperation() {
    @Override
    public void run(BatchDatabase batchDb) {

        Collection c2 = batchDb.collection("collection2");
        {{/ helpers.codedim }}
        // WRONG: Only mutations on c2 are atomic since c1 reference
        // was obtained from Database and not BatchDatabase.
        c1.put("myKey", "myValue");
        c2.put("myKey", "myValue");
        {{# helpers.codedim }}
        // No need to commit. RunInBatch will commit and retry if necessary.
    }
}, new Database.BatchOptions());
{{/ helpers.codedim }}
```

### BeginBatch
`BeginBatch` is an alternative approach to starting a batch operation. Unlike
`RunInBatch`, it does not manage retries and commit/aborts. They are left
to the developers to manage themselves.

```Java
BatchDatabase batchDb = db.beginBatch(new Database.BatchOptions());

Collection c1 = batchDb.collection("collection1");
Collection c2 = batchDb.collection("collection2");

c1.put("myKey", "myValue");
c2.put("myKey", "myValue");

batchDb.commit();
```

{{# helpers.warning }}
## Warning
Using collection references obtained from a `BatchDatabase` after the batch is
committed or aborted will throw exceptions.

**The following code snippet demonstrates the *WRONG* way of using batches.**
{{/ helpers.warning }}

```Java
// WRONG: c1 is NOT part of the batch.
Collection c1 = db.collection("collection1");
{{# helpers.codedim }}
BatchDatabase batchDb = db.beginBatch(new Database.BatchOptions());

// c2 is part of the batch.
Collection c2 = batchDb.collection("collection2");
{{/ helpers.codedim }}

// WRONG: Only mutations on c2 are atomic since c1 reference was obtained
// from Database and not BatchDatabase.
c1.put("myKey", "myValue");
c2.put("myKey", "myValue");

batchDb.commit();

// WRONG: Throws exception since c2 is from an already committed batch.
c2.put("myKey", "myValue");

```

# Summary

* Use batches to group operations that are logically related.
* Use the recommended `runInBatch` method to perform batch operations to
get the added benefit of automatic retries and commit/abort.
* Ensure all collection references are obtained from `BatchDatabase` otherwise
mutations may not be part of a batch.