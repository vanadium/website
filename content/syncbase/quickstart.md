= yaml =
title: Quick Start
layout: syncbase
toc: true
= yaml =

# Setup
This tutorial uses Android Studio, but feel free to use your IDE of choice.

## Create the Project
We will start by creating an empty project in Android Studio
`File -> New -> Project`.
Select `API 21` or above for the Minimum SDK and pick `Empty Activity` as the
template.

# Install Syncbase
Syncbase's Android library is published to both [JCenter] and [MavenCentral].
To install the library, add the following to your `build.gradle` file.

```
dependencies {
  compile 'io.v:vanadium-android:2.1.3+'
}
```

# Setup Cloud Syncbase
Head to [https://sb-allocator.v.io/](https://sb-allocator.v.io/) to setup a free
developer cloud Syncbase instance.

Make note of the Syncbase **Address** and the **Blessing** for your cloud
instance, they are required by the Syncbase API during initialization.

{{# helpers.info }}
## Please note
Requiring a cloud Syncbase is temporary. We are planning to allow the API to be
used without a cloud Syncbase soon.
{{/ helpers.info }}

# Use Syncbase
In your `MainActivity`, import Syncbase and read/write some data!

```
{{# helpers.codedim }}
import android.util.Log;
{{/ helpers.codedim }}
import io.v.syncbase.*;

{{# helpers.codedim }}
@Override
public void onCreate() {
    super.onCreate();
{{/ helpers.codedim }}

  Users.loginWithDefaultAccount();

  DatabaseOptions dbOpt = new DatabaseOptions();
  dbOpt.cloudSyncbaseAddress = '<Your Cloud Syncbase Address>';
  dbOpt.cloudSyncbaseBlessing = '<Your Cloud Syncbase Blessing>';

  Database database = Syncbase.getDatabase(dbOpt);

  Collection collection = database.collection('myCollection');

  collection.put("myKey", "myValue");

  String value = collection.get('myKey', String.class);

  // Prints "Value is: myValue"
  Log.i("info", "Value is: " + value);

{{# helpers.codedim }}
}
{{/ helpers.codedim }}
```

**That's all!** You are now using Syncbase!

# Got 10 more minutes?
Let's create a simple *Dice Roller* app and see it sync peer-to-peer in action!

<a href="/syncbase/first-app.html" class="button-passive">
Create your first app
</a>


[JCenter]: https://bintray.com/vanadium/io.v/vanadium-android
[MavenCentral]: http://repo1.maven.org/maven2/io/v/vanadium-android
