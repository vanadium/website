= yaml =
title: Data Flow
layout: syncbase
sort: 2
toc: true
= yaml =

{{# helpers.hidden }}
<!-- @setupEnvironment @test -->
```
export PROJECT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/tmp.XXXXXXXXXX")
export FILE=$PROJECT_DIR/app/src/main/java/io/v/syncbase/example/DataFlow.java
cp -r $JIRI_ROOT/website/tools/android_project_stubs/example/* $PROJECT_DIR
cat - <<EOF >> $PROJECT_DIR/app/build.gradle
dependencies {
  compile 'io.v:syncbase:0.1.7'
}
EOF
cat - <<EOF > $FILE
package io.v.syncbase.example;
import io.v.syncbase.Collection;
import io.v.syncbase.Database;
import io.v.syncbase.Syncbase;
import io.v.syncbase.WatchChange;
import io.v.syncbase.exception.SyncbaseException;
import android.util.Log;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
public class DataFlow {
  Database db;
  class Task {}
  void main() throws SyncbaseException {
EOF
```
{{/ helpers.hidden }}

# Introduction

Syncbase API is designed to encourage writing reactive applications where the app
updates its UI as data in Syncbase changes. Since Syncbase is a synchronized store
the source of data changes might be local or remote as local Syncbase syncs with
other peers.

The Watch method is the recommended way of retrieving existing data and watching
for changes. Both local and synced mutations are surfaced in the watch stream.
This allows developers to stay agnostic to the source of data changes
and use the same code to handle local and synced changes alike.

Local mutations are surfaced in the watch stream within milliseconds, which
allows apps to be built with unidirectional data flow. Instead of updating the
UI optimistically, UI actions can simply mutate Syncbase data. The watch stream
will quickly receive local changes and trigger the necessary UI updates.

<img src="/images/syncbase-guide-data-flow.png" alt="Unidirectional Data Flow using the Watch method">

# Reading and Watching Data
`addWatchChangeHandler` on `Database` can be used to register a handler that will
be called with both initial existing data and any changes to the data later.

Let's consider a simple Todos application where each collection corresponds to
a Todo list and rows in each collection are the tasks. We can use the Watch method
to maintain an in-memory representation of our data model the UI renders
from. UI actions such as adding new task or deleting one simply do a `put` or
`delete` on the corresponding collection.

<!-- @addWatchHandler @test -->
```
cat - <<EOF >> $FILE
db.addWatchChangeHandler(new Database.WatchChangeHandler() {

  @Override
  public void onInitialState(Iterator<WatchChange> values) {
    // onInitialState is called with all of existing data in Syncbase.
    // Although the value type is WatchChange, since this is existing
    // data, there will not be any values with ChangeType == DELETE_CHANGE
    while (values.hasNext()) {
      updateState(values.next());
    }

    // Trigger UI update
  }

  @Override
  public void onChangeBatch(Iterator<WatchChange> changes) {
    // onChangeBatch is called whenever changes are made to the data.
    // Changes that are part of the same batch are presented together,
    // otherwise changes iterator may only contain a single change.
    while (changes.hasNext()) {
      updateState(changes.next());
    }

    // Trigger UI update
  }

  @Override
  public void onError(Throwable t) {
    // Handle error
  }
});
EOF
```

{{# helpers.hidden }}
<!-- @closeMainFunction @test -->
```
cat - <<EOF >> $FILE
  }
EOF
```
{{/ helpers.hidden }}

Modeling our in-memory state as a map of Todolist-Id to a map of (Task-Id, Task)
<!-- @updateState @test -->
```
cat - <<EOF >> $FILE
HashMap<String, Map<String, Task>> state = new HashMap<String, Map<String, Task>>();

// Update the state based on the changes.
void updateState(WatchChange change) {
  try {
    String collectionId = change.getCollectionId().encode();
    String rowKey = change.getRowKey();

    if(change.getChangeType() == WatchChange.ChangeType.PUT) {
      if(!state.containsKey(collectionId)) {
        state.put(collectionId, new HashMap<String, Task>());
      }
      Task rowValue = change.getValue(Task.class);
      state.get(collectionId).put(rowKey, rowValue);

    } else if(change.getChangeType() == WatchChange.ChangeType.DELETE) {
      state.get(collectionId).remove(rowKey);
    }
  } catch (SyncbaseException e) {
    Log.e("DataFlowExample", "update state error", e);
  }
}
EOF
```

{{# helpers.info }}
### Tip
`db.removeAllWatchChangeHandlers()` can be used in activity's `onDestroy`
to remove all registered watch handlers.
{{/ helpers.info }}

In most cases, source of a change should be irrelevant to the application.
However `watchChange.isFromSync()` can tell you if a change is due to a local
mutation or is synced from a remote Syncbase.

# Summary
* Syncbase's Watch method is designed to help build reactive applications.
* Watch surfaces both local and synced data changes.
* We recommend using the Watch method to keep an up-to-date in-memory state that
the UI renders from.

{{# helpers.hidden }}
<!-- @compileSnippets_mayTakeMinues @test -->
```
cat - <<EOF >> $FILE
}
EOF
cd $PROJECT_DIR && ./gradlew assembleRelease
```
{{/ helpers.hidden }}