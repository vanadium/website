= yaml =
title: Data Model
layout: syncbase
sort: 1
toc: true
= yaml =

{{# helpers.hidden }}
<!-- @setupEnvironment @test -->
```
export PROJECT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/tmp.XXXXXXXXXX")
export FILE=$PROJECT_DIR/app/src/main/java/io/v/syncbase/example/DataModel.java
cp -r $JIRI_ROOT/website/tools/android_project_stubs/example/* $PROJECT_DIR
cat - <<EOF >> $PROJECT_DIR/app/build.gradle
dependencies {
  compile 'io.v:syncbase:0.1.4'
}
EOF
cat - <<EOF > $FILE
package io.v.syncbase.example;
import io.v.syncbase.*;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
public class DataModel {
  Database db;
  void main() {
EOF
```
{{/ helpers.hidden }}

# Introduction
Syncbase is a key-value storage system that handles both structured data and
blobs. The data is organized by the following hierarchy:

* [Database](#database): An app is pre-configured to have a single database
which may contain any number of collections.
* [Collection](#collections): A collection is a set of key-value pairs
(rows). Collections are the unit of access control and sharing.
* [Row](#rows): Each row contains a single key-value pair. Keys are strings and
the values are designed for both [structured data](#structured-data) and
blobs<sup>\*</sup>. Values in the rows of a collection can be heterogeneous
or based on a pre-defined [schema](#schema).

<sup>\*</sup>blobs are on our [roadmap](/community/roadmap.html).

# Database
Database is the entry point to the Syncbase API and provides functionality to
create, watch and share collections, and to perform batch operations.

There is a pre-configured database for each app. `Syncbase.getDatabase()` is
used to initialize Syncbase and get a reference to the app's database.

<!-- @createDatabase @test -->
```
cat - <<EOF >> $FILE
Syncbase.DatabaseOptions options = new Syncbase.DatabaseOptions();
// dbOpt.cloudSyncbaseAddress = "<Your Cloud Syncbase Address>";
// dbOpt.cloudSyncbaseBlessing = "<Your Cloud Syncbase Blessing>";

Syncbase.database(new Syncbase.DatabaseCallback() {
  @Override
  public void onSuccess(final Database db) {
    // Use database to interact with Syncbase.
  }
}, options);
EOF
```

Other database options include ability to set the directory where data files
are stored and whether collections should automatically sync across a user's
devices or not (true by default).

[Database API reference](/syncbase/api-reference.html#database)


# Collections

Collections in Syncbase are used to group related rows together and are the
unit of access control and sharing.

By default, collection data is synced among the creator's devices. Collections
can also be shared with other users.

The sharing mechanism is based on *Syncgroups*. Each collection has a default
Syncgroup that is used to sync data to the user's other devices. By inviting
other users to join this pre-defined Syncgroup, one can share the collection
with others. When inviting others to join a collection's Syncgroup, one can
specify different levels of access such as `Read`, `ReadWrite` or
`ReadWriteAdmin`.

Collections created by all users live in the same namespace. To avoid collisions,
the system automatically prepends the user's identity (blessing) to the
Collection ID. The developer still needs to think about collisions, however.
The user might use one device while offline and then switch to another device
while still offline. When those two devices sync with each other, should the
Collections merge or stay separate? If the developer wants them to stay separate,
the collection IDs should include a UUID. If the developer wants them to merge,
they should use a predictable name (example: "preferences"). Collection names
are restricted to alphanumeric characters plus underscore and can have a maximum
length of 64 bytes.

<!-- @createCollection @test -->
```
cat - <<EOF >> $FILE
String collectionName = UUID.randomUUID().toString();
Collection collection = db.collection(collectionName);

String rowKey = UUID.randomUUID().toString();
collection.put(rowKey, "myValue");

String myValue = collection.get(rowKey, String.class);

collection.delete(rowKey);
EOF
```

As mentioned earlier, collections are synced across user's devices by default
but one can set `withoutSyncgroup` to `false` on
`CollectionOptions` to make a local-only collection that will not sync with
any other peer.

[Collection API reference](/syncbase/api-reference.html#collection)


# Rows

A row refers to a key-value pair in a collection.

## Keys

Keys are strings and normally UUIDs, however there are no restrictions on what
keys can be. All UTF-8 strings are valid and there is no limit on key length.

It can be beneficial to use hierarchical keys to facilitate prefix-matching
and/or filtering. This can be done by using a known separator such as `/`.
For example, data model for a folder/file storage system may design a key space
such as:

{{# helpers.code }}
folder1
folder1/doc1
folder1/folder2
folder1/folder2/doc2
{{/ helpers.code }}

## Structured Data

Syncbase supports [POJO](https://en.wikipedia.org/wiki/Plain_Old_Java_Object)
as values and takes case of serialization. POJO classes must have an empty
constructor.

<!-- @addPojoToCollection @test -->
```
cat - <<EOF >> $FILE
class MyPojo {
  String foo;
  Integer bar;
  List<MyPojo> baz;

  public MyPojo() {
    foo = null;
    bar = null;
    baz = new ArrayList<MyPojo>();
  }
}

MyPojo pojoIn = new MyPojo();
collection.put("myKey", pojoIn);
MyPojo pojoOut = collection.get("myKey", MyPojo.class);
EOF
```

# Example Models

To validate the Syncbase data model, we wrote design docs for a wide variety of
apps. These docs focused on the interactions with Syncbase and the schema they
would use for storage and synchronization. There are many variations on the
features in the apps and many ways to implement those features, so these docs
are not intended to represent the only way to build these apps. Instead, these
docs are intended to provide inspiration while designing your own apps.

## Coffee Catalog

Allows a user to browse and place orders from a catalog containing coffee and
related paraphernalia.

[Design Doc](/syncbase/designdocs/coffee-catalog.html)

## Croupier

Allows users to organize and play peer-to-peer card games together.
The Syncbase schema supports general card games, and it is up to each
application to support games (e.g., Hearts, Solitaire, etc.).

[Design Doc](/syncbase/designdocs/croupier.html)

## SyncSlides

Peer-to-peer slide presentation.  Allows audience to ask questions.
Presenter can delegate control of the presentation to an audience member
temporarily.

[Design Doc](/syncbase/designdocs/syncslides.html)

## Brokerage

The Brokerage app allows a user to invest in the stock market and monitor the
performance of the portfolio.  Security is of utmost importance.
The portfolio can be browsed while offline.  Some non-critical data
(e.g., stock watchlist) may be shared in read-only mode with other apps.
There is no sharing between user accounts.

[Design Doc](/syncbase/designdocs/brokerage.html)

{{# helpers.hidden }}
<!-- @compileSnippets_mayTakeMinutes @test -->
```
cat - <<EOF >> $FILE
  }
}
EOF
cd $PROJECT_DIR && ./gradlew assembleRelease
```
{{/ helpers.hidden }}
