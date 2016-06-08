= yaml =
title: Your First App
layout: syncbase
toc: true
= yaml =

{{# helpers.warning }}
## Work in Progress!
We're actively working on finishing up the Syncbase API and implementation.
The code below compiles, but may not execute successfully. Please join
our [mailing list](/community/mailing-lists.html) for updates.
{{/ helpers.warning }}

# Introduction

In this quick tutorial, we will build a *Dice Roller* Android app where
one can simply generate a random number between 1-6 and have it sync
across multiple devices peer-to-peer, even with Wi-Fi turned off!

<div class="rows">
  <img style="width:250px" src="/images/syncbase-dice-device-1.gif">
</div>

# Setup
This tutorial uses Android Studio, but feel free to use your IDE of choice.

## Create the Project
We will start by creating an empty project in Android Studio
`File -> New -> Project`.
Select `API 21` or above for the Minimum SDK and pick `Empty Activity` as the
template.

## Install Syncbase
Add the following to your `build.gradle` file.

```
dependencies {
  compile 'io.v:vanadium-android:2.1.3+'
}
```

## Setup Cloud Syncbase
Head to [https://sb-allocator.v.io/](https://sb-allocator.v.io/) to setup a free
developer cloud Syncbase instance or access your existing one.

Make note of the Syncbase **Address** and the **Blessing** for your cloud
instance, they are required by the Syncbase API during initialization.

{{# helpers.info }}
## Please note
Requiring a cloud Syncbase is temporary. We are planning to allow the API to be
used without a cloud Syncbase very soon.
{{/ helpers.info }}

## Initialize Syncbase

**MainActivity.java**
```
{{# helpers.codedim }}
package io.v.myfirstsyncbaseapp;

import android.support.v7.app.AppCompatActivity;

import android.os.Bundle;
import android.util.Log;
{{/ helpers.codedim }}
import io.v.syncbase.*;

{{# helpers.codedim }}
public class MainActivity extends AppCompatActivity {

  @Override
  protected void onCreate(Bundle savedInstanceState) {

    super.onCreate(savedInstanceState);
    {{/ helpers.codedim }}
    User currUser = Users.loginWithDefaultAccount();

    DatabaseOptions dbOpt = new DatabaseOptions();
    dbOpt.cloudSyncbaseAddress = '<Your Cloud Syncbase Address>'
    dbOpt.cloudSyncbaseBlessing = '<Your Cloud Syncbase Blessing>'

    Database db = Syncbase.getDatabase();

    Log.i("info", "Welcome: " + currUser.getEmail());
    {{# helpers.codedim }}
    setContentView(R.layout.activity_main);
  }
}
{{/ helpers.codedim }}
```
Now, let's run the app to make sure login and Syncbase initialization are working.
After running, you should see `Welcome <email>` in logcat under Android Monitor
or in the console.

# UI Code
The user interface is just a `TextView` to display the dice roll
result and a `Button`s to roll the dice.
Here is the UI code

**activity_main.xml**
```
{{# helpers.codedim }}
<?xml version="1.0" encoding="utf-8"?>
<RelativeLayout xmlns:android="http://schemas.android.com/apk/res/android"
  xmlns:tools="http://schemas.android.com/tools"
  android:layout_width="match_parent"
  android:layout_height="match_parent"
  android:paddingBottom="@dimen/activity_vertical_margin"
  android:paddingLeft="@dimen/activity_horizontal_margin"
  android:paddingRight="@dimen/activity_horizontal_margin"
  android:paddingTop="@dimen/activity_vertical_margin"
  tools:context="io.v.myfirstsyncbaseapp.MainActivity">
  {{/ helpers.codedim }}
  <TextView
    {{# helpers.codedim }}
    android:layout_width="wrap_content"
    android:layout_height="wrap_content"
    {{/ helpers.codedim }}
    android:text="Dice Not Rolled yet"
    android:id="@+id/textViewResult"
    {{# helpers.codedim }}
    android:layout_marginTop="36dp"
    android:textSize="30dp"
    android:layout_alignParentTop="true"
    android:layout_centerHorizontal="true" />
  {{/ helpers.codedim }}
  <Button
    {{# helpers.codedim }}
    style="?android:attr/buttonStyleSmall"
    android:layout_width="wrap_content"
    android:layout_height="wrap_content"
    {{/ helpers.codedim }}
    android:text="Roll the Dice!"
    android:id="@+id/buttonRoll"
    {{# helpers.codedim }}
    android:layout_marginTop="40dp"
    android:layout_below="@+id/textViewResult"
    android:layout_centerHorizontal="true" />
</RelativeLayout>
{{/ helpers.codedim }}
```
Running the project at this point should result in the following UI:

<img style="width:250px" src="/images/syncbase-dice-1.png" alt="Screenshot of the Dice Roll app">

# Data Binding
The data model for this app is simple. We just need a single collection (`dice`)
and a single key/value pair (`'result'`, `int`) to store the result of the dice
roll.

To bind Syncbase data with the UI, we will create a unidirectional data flow
using Syncbase's Watch API to handle both local and synced mutation.

With this model, on a dice roll we can change the value in the local Syncbase
without updating the UI at all. The local mutation will propagate back
through the Watch handler with very low latency enabling us to only update the
UI in a single place, regardless of whether the new value is local or was synced
from a remote device.

<img src="/images/syncbase-dice-data-flow.png" alt="Unidirectional Data Flow using Watch API">

Now let's hook up this model to our code.

```
{{# helpers.codedim }}
package io.v.myfirstsyncbaseapp;

import android.support.v7.app.AppCompatActivity;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.widget.Button;
import android.widget.TextView;

import java.util.Iterator;
import java.util.Random;

import io.v.syncbase.*;

public class MainActivity extends AppCompatActivity {

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);

    User currUser = Users.loginWithDefaultAccount();

    DatabaseOptions dbOpt = new DatabaseOptions();
    dbOpt.cloudSyncbaseAddress = '<Your Cloud Syncbase Address>'
    dbOpt.cloudSyncbaseBlessing = '<Your Cloud Syncbase Blessing>'

    Database db = Syncbase.getDatabase();

    Log.i("info", "Welcome: " + currUser.getEmail());

    setContentView(R.layout.activity_main);

    {{/ helpers.codedim }}

    // On dice roll, put a new random number under key "result"
    // in the "dice" collection.
    final Button button = (Button) findViewById(R.id.buttonRoll);
    button.setOnClickListener(new View.OnClickListener() {
      public void onClick(View v) {
        int randomNumber =  new Random().nextInt(6) + 1;

        Collection diceCollection = db.collection("dice");
        diceCollection.put("result", randomNumber);
      }
    });

    // Watch the database and update the UI whenever a new value
    // is encountered.
    db.removeWatchChangeHandler(new Database.WatchChangeHandler() {

      void onInitialState(Iterator<WatchChange> values) {
        // onInitialState is called with any existing data in Syncbase.
        // Since we only have a single collection, single key/value,
        // there can only be 0 or 1 values.
        if (values.hasNext()) {
          int result = (int) values.next().getValue(int.class);
          updateResult(result);
        }
      }

      void onChangeBatch(Iterator<WatchChange> changes) {
        // onChangeBatch is called with any updates to the data.
        // Since we only have a single collection, single key/value.
        // there can only be 1 WatchChange whenever the value is mutated
        // and the type of change would always be `put` in our case.
        int result = (int) changes.next().getValue(int.class);
        updateResult(result);
      }

      void onError(Exception e) {
        // Something went wrong. Watch is no longer active.
      }
    });
  }

  private void updateResult(int newValue) {
    final TextView result = (TextView) findViewById(R.id.textViewResult);
    result.setText(String.valueOf(newValue));
  }
{{# helpers.codedim }}
}
{{/ helpers.codedim }}
```

# Running The App
To see the data sync between user's devices in a peer-to-peer fashion, we can
run the app on two different devices and then turn off Wi-Fi and see it still
sync using Bluetooth.

When running the app from Android Studio, you can select multiple devices in
the `Select a Deployment Target`. If you prefer to use the command line
[Multi-Device ADB (madb)](https://github.com/vanadium/madb) is an open-source
tool that makes it easy to run Android apps on multiple devices.

{{# helpers.info }}
## Please note
Internet connectivity is required the first time the app is run to authenticate
the user and generate an offline auth certificate.
Subsequence runs do not require Internet connectivity.
{{/ helpers.info }}

After running the application on 2 or more devices with Internet connectivity,
ensure Bluetooth is enabled on both devices and turn off Wi-Fi, the dice rolls
should still sync between the devices just fine!

<div class="rows">
  <img style="width:250px" src="/images/syncbase-dice-device-1.gif">
</div>

# Want to dive deeper?
Checkout the [Tutorial] to build a full-fledged Todo app and learn more Syncbase
features such as sharing, batches and discovery.

<a href="/syncbase/tutorial/introduction.html" class="button-passive">
Build a collaborative Todo app
</a>

[Tutorial]: /syncbase/tutorial/introduction.html
