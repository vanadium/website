= yaml =
title: "Location Service in Android"
fullTitle: "Location Service in Android"
layout: java_tutorial
wherein: you build an Android phone locator service.
sort: 2
toc: true
prerequisites: {}
= yaml =

# Introduction

In this tutorial, we will build a very simple Android application that will
create a Vanadium server on the phone. When queried by an authorized client,
the server will return the phone's physical location (latitude and longitude).

The tutorial will demonstrate some Android-specific aspects of the Vanadium
implementation. It will also show that Vanadium allows clients to work across
NAT networks transparently.

We will be building three software components in this tutorial:

  * the Vanadium server that responds to location requests
  * the Android service that starts the Vanadium server
  * the Android activity that sets up our security environment and starts the
    Android service

Here's a screenshot of the tutorial program built and running on a Nexus 5
emulator.

![Location service activity](/images/tut/location-service-activity.png)

# Setting up the project

In this tutorial, we will use the [Gradle][gradle] build tool to build the
project. There is no requirement that Vanadium Java projects use Gradle, but
it's the easiest way to get started. See the [installation
instructions][gradleinstall] for details. The remainder of the tutorial will
assume that you have the `gradle` program in your PATH.

If you are familiar with [Android Studio][studio], we encourage you to
use it for this tutorial.

## Build file

The first step to defining a Gradle project is to create a `build.gradle` file
in the project root directory.

First, create a new project directory.

```
mkdir location
cd location
```

{{# helpers.hidden }}
<!-- @setupEnvironment @test -->
```
JAVA_PROJECT_DIR=$(mktemp -d /tmp/tmp.XXXXXXXXXX)
cd $JAVA_PROJECT_DIR
export PATH=$JIRI_ROOT/third_party/java/gradle:$PATH
```
{{/ helpers.hidden }}

Now, create a `build.gradle` file:

<!-- @createBuildFile @test -->
```
cat <<EOF > build.gradle

buildscript {
    repositories {
        mavenCentral()
    }
    dependencies {
        // This introduces the Android plugin to make building Android
        // applications easier.
        classpath 'com.android.tools.build:gradle:1.3.1'

        // We are going to define a custom VDL service. The Vanadium
        // Gradle plugin makes that easier, so let's use that.
        classpath 'io.v:gradle-plugin:0.5'

        // Use the Android SDK manager, which will automatically download
        // the required Android SDK.
        classpath 'com.jakewharton.sdkmanager:gradle-plugin:0.12.0'
    }
}

// Make our lives easier by automatically downloading the appropriate Android
// SDK.
apply plugin: 'android-sdk-manager'

// It's an Android application.
apply plugin: 'com.android.application'

// It's going to use VDL.
apply plugin: 'io.v.vdl'

repositories {
    mavenCentral()
}

android {
    compileSdkVersion 19
    buildToolsVersion "23.0.1"
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_7
        targetCompatibility JavaVersion.VERSION_1_7
    }
    packagingOptions {
        exclude 'META-INF/LICENSE.txt'
        exclude 'META-INF/NOTICE.txt'
    }
}

dependencies {
    compile 'io.v:vanadium:0.1'
    compile 'io.v:vanadium-android:0.1'
}

vdl {
    inputPaths += 'src/main/java'
}

EOF
```

# Defining the Location Server

We're going to create a Vanadium server on the Android phone. The easiest way to
do this is to define it in [VDL][vdl].

<!-- @createVdlInterface @test -->
```
mkdir -p src/main/java/io/v/location
cat <<EOF > src/main/java/io/v/location/location.vdl
package location

type LatLng struct {
        // The latitude of the phone, in degrees.
        Lat float64

        // The longitude of the phone, in degrees.
        Lng float64
}

type Location interface {
        // The one method that we will support. When called, returns the
        // physical location of the phone or an error if it could not be
        // determined.
        Get() (LatLng | error)
}

EOF
```

As you can see, we provide a single 'Get' method to get the location of the
phone. Let's generate the VDL source just to make sure everything worked.

<!-- @generateVdlSource @test -->
```
gradle vdl
```

You should see output like the following:

{{# helpers.code }}
:prepareVdl
:extractVdl
:generateVdl
signature
time
vdltool
io/v/location
:removeVdlRoot
:vdl

BUILD SUCCESSFUL
{{/ helpers.code }}

The `io/v/location` line indicates that VDL tool has processed your input file.
If you now look inside the `generated-src` directory, you'll find the following
entries:

{{# helpers.code }}
generated-src/vdl/io/v/location/LocationClientFactory.java
generated-src/vdl/io/v/location/LocationServer.java
generated-src/vdl/io/v/location/LocationClientImpl.java
generated-src/vdl/io/v/location/LatLng.java
generated-src/vdl/io/v/location/LocationClient.java
generated-src/vdl/io/v/location/LocationServerWrapper.java
{{/ helpers.code }}

## Implementation

Now we must provide an implementation for the LocationServer. We'd like this
server to be long-lived, so we're going to use an [Android Service][service].

Create `src/main/java/io/v/location/LocationService.java`:

<!-- @generateLocationServerImpl @test -->
```
cat <<EOF > src/main/java/io/v/location/LocationServerImpl.java
package io.v.location;

import android.location.Criteria;
import android.location.Location;
import android.location.LocationManager;

import io.v.android.v23.V;
import io.v.v23.context.VContext;
import io.v.v23.rpc.ServerCall;
import io.v.v23.verror.VException;

/**
 * This class implements the VDL interface we defined above.
 */
public class LocationServerImpl implements LocationServer {
   // We're going to use Android's LocationManager to get the phone's
   // physical location.
   private final LocationManager manager;

   LocationServerImpl(LocationManager manager) {
       this.manager = manager;
   }

   @Override
   public LatLng get(VContext context, ServerCall call) throws VException {
       Criteria criteria = new Criteria();
       criteria.setAccuracy(Criteria.NO_REQUIREMENT);
       String provider = manager.getBestProvider(criteria, true);
       if (provider == null || provider.isEmpty()) {
           throw new VException("Couldn't find any location providers on the device.");
       }
       Location location = manager.getLastKnownLocation(provider);
       if (location == null) {
           throw new VException("Got null location.");
       }
       return new LatLng(location.getLatitude(), location.getLongitude());
   }
}
EOF
```

# Android service

Long-running tasks, like a Vanadium server, belong in Android services. In this
section we implement an Android service that starts our `LocationServer` and
mounts it into the Vanadium namespace. Please see the [Android
documentation][service] for detailed information about Services.

Recall that Vanadium is secure. Given that this service is going to be
responsible for mounting objects into the Vanadium namespace, we need to:

  * trust the remote mounttable server
  * present to that server a set of acceptable blessings

This service implementation will assume that this information is passed into the
`onCreate` method.

## Implementation

<!-- @generateLocationService @test -->
```
cat <<EOF > src/main/java/io/v/location/LocationService.java
package io.v.location;

import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.location.LocationManager;
import android.os.IBinder;
import android.widget.Toast;

import com.google.common.collect.Lists;

import java.util.List;

import io.v.android.v23.V;
import io.v.v23.context.VContext;
import io.v.v23.rpc.ListenSpec;
import io.v.v23.rpc.Server;
import io.v.v23.security.BlessingPattern;
import io.v.v23.security.Blessings;
import io.v.v23.security.VCertificate;
import io.v.v23.security.VPrincipal;
import io.v.v23.security.VSecurity;
import io.v.v23.verror.VException;
import io.v.v23.vom.VomUtil;

public class LocationService extends Service {
    public static final String BLESSINGS_KEY = "Blessings";
    private VContext baseContext;

    @Override
    public IBinder onBind(Intent intent) {
        return null;  // Binding not allowed
    }

    /**
     * This method decodes the passed-in blessings and calls
     * startLocationServer to actually start and mount the
     * Vanadium server.
     */
    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        // Initialize Vanadium.
        baseContext = V.init(this);

        // Fetch the blessings from the intent. The activity that is starting
        // the service must populate this field.
        String blessingsVom = intent.getStringExtra(BLESSINGS_KEY);

        if (blessingsVom == null || blessingsVom.isEmpty()) {
            String msg = "Could not start LocationService: "
                + "null or empty encoded blessings.";
            Toast.makeText(this, msg, Toast.LENGTH_LONG).show();
            return START_REDELIVER_INTENT;
        }

        try {
            Blessings blessings = (Blessings) VomUtil.decodeFromString(
                blessingsVom, Blessings.class);
            if (blessings == null) {
                String msg = "Couldn't start LocationService: "
                    + "null blessings.";
                Toast.makeText(this, msg, Toast.LENGTH_LONG).show();
                return START_REDELIVER_INTENT;
            }

            // We have blessings, start the server!
            startLocationServer(blessings);
        } catch (VException e) {
            String msg = "Couldn't start LocationService: " + e.getMessage();
            Toast.makeText(this, msg, Toast.LENGTH_LONG).show();
        }
        return START_REDELIVER_INTENT;
    }

    /**
     * This method starts and mounts the Vanadium location server with the given
     * blessings.
     */
    public void startLocationServer(Blessings blessings) throws VException {
        // Principal represents our identity within the Vanadium system.
        VPrincipal principal = V.getPrincipal(baseContext);

        // Provide the given blessings when anybody connects to us.
        principal.blessingStore().setDefaultBlessings(blessings);

        // Also, provide these blessings when we connect to other services (for
        // example, when we talk to the mounttable).
        principal.blessingStore().set(blessings, new BlessingPattern("..."));

        // Trust these blessings and all the "parent" blessings.
        VSecurity.addToRoots(principal, blessings);

        // Our security environment is now set up. Let's find a home in the
        // namespace for our service.
        String mountPoint;
        String prefix = mountNameFromBlessings(blessings);

        if ("".equals(prefix)) {
            throw new VException("Could not determine mount point: "
                + "no username in blessings?");
        } else {
            mountPoint = "users/" + prefix + "/location";
            String msg = "Mounting server at " + mountPoint;
            Toast.makeText(this, msg, Toast.LENGTH_LONG).show();
        }

        // Now create the server and mount it.
        LocationServer locationServer = new LocationServerImpl(
            (LocationManager) getSystemService(Context.LOCATION_SERVICE));

        // Use Vanadium's production proxy server for NAT traversal. None of
        // your data is visible to the proxy server because it's all encrypted.
        ListenSpec spec = V.getListenSpec(baseContext).withProxy("proxy");

        // Finally, the magic moment!
        Server server = V.getServer(
            V.withNewServer(V.withListenSpec(baseContext, spec),
                mountPoint, locationServer, null));

        Toast.makeText(this, "Success!", Toast.LENGTH_SHORT).show();
    }

    /**
     * This method finds the last certificate in our blessing's certificate
     * chains whose extension contains an '@'. We will assume that extension to
     * represent our username.
     */
    private static String mountNameFromBlessings(Blessings blessings) {
        for (List<VCertificate> chain : blessings.getCertificateChains()) {
            for (VCertificate certificate : Lists.reverse(chain)) {
                if (certificate.getExtension().contains("@")) {
                    return certificate.getExtension();
                }
            }
        }
        return "";
    }
}
EOF
```

# Android activity

We have defined a service, now we need an [activity] to run it. This activity
has only two UI elements: a button to choose a Vanadium blessing and a button to
start the location service.

## Security and the Account Manager

Now would be a good time to talk some more about security. Since this tutorial
involves talking to the Vanadium root mounttable, we're going to need a blessing
issued by the Vanadium identity service. The details of how a trusted channel is
established between two authenticated endpoints is beyond the scope of this
tutorial. To make a long story short: we're going to delegate all of this to a
special Android application called the Account Manager.

You should download and install the account manager using the following
commands:

```
wget https://v.io/account_manager-release.apk
```

```
$HOME/.android-sdk/platform-tools/adb install -r account_manager-release.apk
```

## Implementation

Assuming that you've installed the account manager, you're ready to implement
the location activity. Typically, Android applications will use declarative XML
layouts, but to keep this tutorial as short as possible, we're going to create
and lay out the UI components manually in Java.

<!-- @defineLocationActivity @test -->
```
cat <<EOF > src/main/java/io/v/location/LocationActivity.java

package io.v.location;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.Toast;

import io.v.android.libs.security.BlessingsManager;
import io.v.android.v23.V;
import io.v.android.v23.services.blessing.BlessingCreationException;
import io.v.android.v23.services.blessing.BlessingService;
import io.v.v23.context.VContext;
import io.v.v23.security.Blessings;
import io.v.v23.verror.VException;
import io.v.v23.vom.VomUtil;

public class LocationActivity extends Activity {
    private static final int BLESSING_REQUEST = 1;

    private VContext mBaseContext;
    private Button chooseBlessingsButton;
    private Button startServiceButton;
    private Blessings blessings;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Initialize Vanadium.
        mBaseContext = V.init(this);

        // Layout our two buttons vertically.
        LinearLayout layout = new LinearLayout(getApplicationContext());
        layout.setOrientation(LinearLayout.VERTICAL);

        // Initially the blessings will be null. Give the user a button to pick
        // the blessings to use.
        chooseBlessingsButton = new Button(getApplicationContext());
        chooseBlessingsButton.setText("Choose blessings...");
        chooseBlessingsButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                fetchBlessings(false);
            }
        });
        layout.addView(chooseBlessingsButton);

        // Once they've picked blessings, this button will be enabled and will
        // allow the user to start the location service.
        startServiceButton = new Button(getApplicationContext());
        startServiceButton.setText("Start listening");
        startServiceButton.setEnabled(false);
        startServiceButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                startLocationService(blessings);
            }
        });
        layout.addView(startServiceButton);

        setContentView(layout);
    }

    /**
     * This method is called when the user clicks the "choose blessings" button.
     * It fires off an intent which will be handled by the Account Manager.
     */
    private void fetchBlessings(boolean startService) {
        Intent intent = BlessingService.newBlessingIntent(this);
        startActivityForResult(intent, BLESSING_REQUEST);
    }

    /**
     * This method will be called once the user has finished selecting their
     * blessings from the Account Manager.
     */
    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        switch (requestCode) {
            case BLESSING_REQUEST:
                try {
                    // The Account Manager will pass us the blessings to use as
                    // an array of bytes. Use VomUtil to decode them...
                    byte[] blessingsVom =
                        BlessingService.extractBlessingReply(resultCode, data);
                    blessings = (Blessings) VomUtil.decode(blessingsVom, Blessings.class);
                    BlessingsManager.addBlessings(this, blessings);
                    Toast.makeText(this, "Success, ready to listen!",
                        Toast.LENGTH_SHORT).show();

                    // Enable the "start service" button.
                    startServiceButton.setEnabled(true);
                } catch (BlessingCreationException e) {
                    String msg = "Couldn't create blessing: " + e.getMessage();
                    Toast.makeText(this, msg, Toast.LENGTH_LONG).show();
                } catch (VException e) {
                    String msg = "Couldn't store blessing: " + e.getMessage();
                    Toast.makeText(this, msg, Toast.LENGTH_LONG).show();
                }
                return;
        }
    }

    /**
     * Finally, this is the start service button handler.
     */
    private void startLocationService(Blessings blessings) {
        try {
            // Recall that the location service expects a Blessings object
            // encoded as a VOM string.
            String blessingsVom = VomUtil.encodeToString(blessings, Blessings.class);
            Intent intent = new Intent(this, LocationService.class);
            intent.putExtra(LocationService.BLESSINGS_KEY, blessingsVom);
            stopService(intent);
            startService(intent);
        } catch (VException e) {
            String msg = String.format(
                    "Couldn't encode blessings %s: %s", blessings, e.getMessage());
            Toast.makeText(this, msg, Toast.LENGTH_LONG).show();
        }
    }
}
EOF
```

# Android manifest file

Android applications require a manifest file. In our case, it's pretty
straightforward:

<!-- @defineManifest @test -->
```
cat <<EOF > src/main/AndroidManifest.xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="io.v.location"
    android:versionCode="1"
    android:versionName="1.0" >

    <uses-sdk
        android:minSdkVersion="21"
        android:targetSdkVersion="21" />

    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

    <application>
        <activity
            android:name=".LocationActivity"
            android:label="Location Service" >
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
        <service
          android:name=".LocationService"
          android:exported="false"
          android:label="Location Service"
          android:process=":LocationService">
        </service>
    </application>
</manifest>
EOF
```

We'll create a resource file to hold some values. The Android Gradle plugin
will fail if no resources are defined.

<!-- @addResources @test -->
```
mkdir -p src/main/res/values
cat <<EOF > src/main/res/values/strings.xml
<resources>
    <string name="app_name">Location</string>
</resources>
EOF
```

# Deploying and running the application

Finally, you're ready to build and deploy your Android application. To do this:

<!-- @assembleRelease @test -->
```
gradle assembleRelease
```

This will produce file named `build/outputs/location-release-unsigned.apk`. You
can install this on your phone:

```
$HOME/.android-sdk/platform-tools/adb \
    install -r build/outputs/location-release-unsigned.apk
```

You will now find your application in your phone's application list. When you
run it, you will need to pick some blessings. Choose your email address from the
account list.

# Calling the server

The server is now running on your phone and listening for connections. Now we
can connect to it from another computer. We'll use the `vrpc` command in the
[Vanadium distribution][vdl]. Once you've installed that, we need to get
ourselves some blessings to talk to the phone.

The Vanadium server that we placed into the Vanadium namespace uses a default
authorizer. This means that it will trust an incoming connection if the client
provides blessings that share a common name with the server.

```
$HOME/v23_release/bin/principal \
    --v23.credentials=/tmp/creds seekblessings

# This command will open a browser. In it, you should sign in to Google using
# the same email address that you used on your phone.
```

Now let's make the call:

```
$HOME/v23_release/bin/vrpc \
    --v23.credentials=/tmp/creds \
    call /users/you@gmail.com/android/io.v.location/location
```

Try making some changes to the phone's network configuration. For example,
disconnect from the Wi-Fi network so that your phone is using a mobile data
connection. Your location requests should still be successful.

# Summary

Congratulations! You have successfully built and run the location service
application on Android.

You have:

  * built a Vanadium-enabled secure location server Android application
  * connected to that application from your desktop
  * observed that changes to the network configuration of the server do not
    affect its ability to receive requests

There are a few things to note:

  * we have used the Account Manager application to authenticate to Google via
    OAuth. While you're more than welcome to use Google to authenticate, you are
    free to come up with your own methods for trusting peers. For example, you
    might want to exchange blessings via [NFC beaming][nfc].
  * to keep the tutorial as small as possible, we did not use the Android
    declarative XML UI framework. You will probably want to use that when
    writing a real application

[activity]: http://developer.android.com/guide/components/activities.html
[client-server]: /tutorials/basics.html
[endpoint]: /glossary.html#endpoint
[gradle]: http://gradle.org/
[gradleinstall]: https://docs.gradle.org/current/userguide/installation.html
[installation]: /installation.html
[name]: /glossary.html#object-name
[service]: http://developer.android.com/guide/components/services.html
[studio]: https://developer.android.com/sdk/index.html
[vdl]: /glossary.html#vanadium-definition-language-vdl-
[nfc]: https://developer.android.com/guide/topics/connectivity/nfc/index.html
