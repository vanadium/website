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
cp -r $JIRI_ROOT/website/tools/android_project_stubs/quickstart/* $PROJECT_DIR
```
{{/ helpers.hidden }}

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

{{# helpers.hide_cat_eof_lines }}
<!-- @addSyncbaseDependency @test -->
```
cat - <<EOF >> $PROJECT_DIR/app/build.gradle
dependencies {
  compile 'io.v:syncbase:0.1.4'
}
EOF
```
{{/ helpers.hide_cat_eof_lines }}

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


{{# helpers.hide_cat_eof_lines }}
<!-- @generateMainActivity @test -->
```
cat - <<EOF | sed 's/{{.*}}//' > $PROJECT_DIR/app/src/main/java/syncbase/io/v/quickstart/MainActivity.java
{{# helpers.codedim}}
package syncbase.io.v.quickstart;

import android.support.v7.app.AppCompatActivity;
import android.os.Bundle;
{{/ helpers.codedim}}
import io.v.syncbase.*;

{{# helpers.codedim}}
public class MainActivity extends AppCompatActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        {{/ helpers.codedim}}
        Syncbase.DatabaseOptions options = new Syncbase.DatabaseOptions();
        // dbOpt.cloudSyncbaseAddress = "<Your Cloud Syncbase Address>";
        // dbOpt.cloudSyncbaseBlessing = "<Your Cloud Syncbase Blessing>";

        Syncbase.database(new Syncbase.DatabaseCallback() {
            @Override
            public void onSuccess(Database db) {

                // Use database to interact with Syncbase.

                Collection collection = db.collection("myCollection");

                collection.put("myKey", "myValue");

                String value = collection.get("myKey", String.class);
            }
        }, options);
        {{# helpers.codedim}}

        setContentView(R.layout.activity_main);
    }
}
{{/ helpers.codedim}}
EOF
```
{{/ helpers.hide_cat_eof_lines }}

**That's all!** You are now using Syncbase!

{{# helpers.hidden }}
<!-- @compile_mayTakeMinutes @test -->
```
cd $PROJECT_DIR && ./gradlew assembleRelease
```
{{/ helpers.hidden }}

# Got 10 more minutes?
Let's create a simple *Dice Roller* app and see it sync peer-to-peer in action!

<a href="/syncbase/first-app.html" class="button-passive">
Create your first app
</a>

[JCenter]: https://bintray.com/vanadium/io.v/vanadium-android
[MavenCentral]: http://repo1.maven.org/maven2/io/v/vanadium-android
