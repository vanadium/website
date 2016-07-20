= yaml =
title: Quick Start
layout: syncbase
toc: true
= yaml =

{{# helpers.warning }}
## Work in Progress!
We're actively working on finishing up the Syncbase API and implementation.
The code below compiles, but may not execute successfully. Please join
our [mailing list](/community/mailing-lists.html) for updates.
{{/ helpers.warning }}

{{# helpers.hidden }}
<!-- @setupEnvironment @test -->
```
export PROJECT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/tmp.XXXXXXXXXX")
cp -r $JIRI_ROOT/website/tools/android_project_stubs/example/* $PROJECT_DIR
```
{{/ helpers.hidden }}

# Setup
This tutorial uses Android Studio, but feel free to use your IDE of choice.

We will start by creating an empty project in Android Studio
`File -> New -> Project`.
Select `API 21` or above for the Minimum SDK and pick `Empty Activity` as the
template.

# Install Syncbase
Syncbase's Android library is published to both [JCenter] and [MavenCentral].
To install the library, add the following to your `build.gradle` file.

<!-- @addSyncbaseDependency @test -->
```
cat - <<EOF >> $PROJECT_DIR/app/build.gradle
dependencies {
  compile 'io.v:syncbase:0.1.7'
}
EOF
```

# Setup Cloud Syncbase
Head to [https://sb-allocator.v.io/](https://sb-allocator.v.io/) to setup a free
developer cloud Syncbase instance.

Make note of the Syncbase **Address** and the **Blessing** for your cloud
instance, they are required by the Syncbase API during initialization.

{{# helpers.info }}
## Note
Requiring a cloud Syncbase is temporary. We are planning to allow the API to be
used without a cloud Syncbase soon.
{{/ helpers.info }}

# Use Syncbase
In your `MainActivity`, import Syncbase and read/write some data!

<!-- @generateMainActivity @test -->
```
cat - <<EOF | sed 's/{{.*}}//' > $PROJECT_DIR/app/src/main/java/io/v/syncbase/example/MainActivity.java
{{# helpers.codedim}}
package io.v.syncbase.example;

import android.content.Context;
import android.os.Bundle;
import android.support.v7.app.AppCompatActivity;
import android.util.Log;
{{/ helpers.codedim}}
import io.v.syncbase.Collection;
import io.v.syncbase.Syncbase;
import io.v.syncbase.exception.SyncbaseException;

{{# helpers.codedim}}
public class MainActivity extends AppCompatActivity {
    private static final String TAG = "QuickStart";

    // Note: Replace CLOUD_NAME and CLOUD_ADMIN with your cloud syncbase name
    // and blessing from https://sb-allocator.v.io
    private static final String CLOUD_NAME = "<cloud name>";
    private static final String CLOUD_ADMIN = "<cloud admin>";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        {{/ helpers.codedim}}
        try {
            String rootDir = getDir("syncbase", Context.MODE_PRIVATE).getAbsolutePath();
            Syncbase.Options options =
                    Syncbase.Options.cloudBuilder(rootDir, CLOUD_NAME, CLOUD_ADMIN)
                            .build();
            Syncbase.init(options);
        } catch (SyncbaseException e) {
            Log.e(TAG, "Syncbase failed to initialize", e);
        }

        Syncbase.loginAndroid(this, new Syncbase.LoginCallback() {
            @Override
            public void onSuccess() {
                Log.i(TAG, "Syncbase is ready");

                // Interact with syncbase!
                try {
                    Collection collection = Syncbase.database().createCollection();
                    collection.put("myKey", "myValue");
                    String value = collection.get("myKey", String.class);
                } catch (SyncbaseException e) {
                    Log.e(TAG, "Syncbase error", e);
                }
            }

            @Override
            public void onError(Throwable e) {
                Log.e(TAG, "Syncbased failed to login", e);
            }
        });
        {{# helpers.codedim}}
    }
}
{{/ helpers.codedim}}
EOF
```

**That's all!** You are now using Syncbase!

{{# helpers.hidden }}
<!-- @compile_mayTakeMinutes @test -->
```
cd $PROJECT_DIR && ./gradlew assembleRelease
```
{{/ helpers.hidden }}

# Got 10 More Minutes?
Let's create a simple *Dice Roller* app and see it sync peer-to-peer in action!

<a href="/syncbase/first-app.html" class="button-passive">
Create your first app
</a>

[JCenter]: https://bintray.com/vanadium/io.v/vanadium-android
[MavenCentral]: http://repo1.maven.org/maven2/io/v/vanadium-android
