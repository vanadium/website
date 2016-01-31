= yaml =
title: "Fortune in Java"
fullTitle: "Fortune in Java"
layout: java_tutorial
wherein: you build a fortune teller service and a client to talk to it.
sort: 1
toc: true
prerequisites: {}
= yaml =

## Introduction

In this tutorial, we will create a fortune teller server and a client to talk to
it. The server will have two methods:

  * `Add`, which adds a fortune to the list of fortunes, and
  * `Get`, which retrieves a random fortune.

## Setting up the project

In this tutorial, we will use the [Gradle][gradle] build tool to build the
project. There is no requirement that Vanadium Java projects use Gradle, but
it's the easiest way to get started. See the [installation
instructions][gradleinstall] for details. The remainder of the tutorial will
assume that you have the `gradle` program in your PATH.

### Build file

The first step to defining a Gradle project is to create a `build.gradle` file
in the project root directory.

First, create a new project directory.

```
mkdir fortuneJava
cd fortuneJava
```

{{# helpers.hidden }}
<!-- @setupEnvironment @test -->
```
JAVA_PROJECT_DIR=$(mktemp -d -t tmp.XXXXXXXXXX)
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
        // Our project is going to use VDL, so we need to depend on the Vanadium
        // Gradle plugin.
        classpath 'io.v:gradle-plugin:0.5'
    }
}

// We're going to be building an application to run
apply plugin: 'application'

// It's going to use VDL
apply plugin: 'io.v.vdl'

// And it's going to be written in Java
apply plugin: 'java'

// This class will contain our server's entry point
mainClassName = 'io.v.tutorial.FortuneTutorial'

repositories {
    mavenCentral()
}

dependencies {
    // We need the Vanadium Java libraries.
    compile 'io.v:vanadium:0.1'
}

vdl {
    // This is where the VDL tool will look for VDL definitions.
    inputPaths += 'src/main/java'
}

EOF
```

## Defining the Fortune service

In Java, we must use [VDL] (Vanadium Definition Language) to define our server
interface. We will reuse the same interface definition from the
[Client/Server Basics tutorial][client-server].
For this tutorial, the fortune teller server definition lives in `src/main/java/io/v/tutorial/fortune.vdl`.
Let's create this file now:

<!-- @createVdlInterface @test -->
```
mkdir -p src/main/java/io/v/tutorial
cat <<EOF > src/main/java/io/v/tutorial/fortune.vdl
package fortune

type Fortune interface {
  // Returns a random fortune.
  Get() (wisdom string | error)
  // Adds a fortune to the set used by Get().
  Add(wisdom string) error
}
EOF
```

As you can see, we provide 'Get' and 'Add' methods to get and add fortunes. We
can now test our VDL file by asking Gradle to generate the corresponding Java
files. Do this by running

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
io/v/tutorial
:removeVdlRoot
:vdl

BUILD SUCCESSFUL
{{/ helpers.code }}

The `io/v/tutorial` line indicates that VDL tool has processed your input file.
If you now look inside the `generated-src` directory, you'll find the following
entries:

{{# helpers.code }}
generated-src/vdl/io/v/tutorial/FortuneServerWrapper.java
generated-src/vdl/io/v/tutorial/FortuneClient.java
generated-src/vdl/io/v/tutorial/FortuneServer.java
generated-src/vdl/io/v/tutorial/FortuneClientImpl.java
generated-src/vdl/io/v/tutorial/FortuneClientFactory.java
{{/ helpers.code }}

### Implementation

Now we must provide an implementation for the FortuneServer.

Create `src/main/java/io/v/tutorial/InMemoryFortuneServer.java`:

<!-- @generateInMemoryFortuneServerImpl @test -->
```
cat <<EOF > src/main/java/io/v/tutorial/InMemoryFortuneServer.java
package io.v.tutorial;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Random;

import io.v.v23.V;
import io.v.v23.context.VContext;
import io.v.v23.naming.Endpoint;
import io.v.v23.rpc.Server;
import io.v.v23.rpc.ServerCall;
import io.v.v23.security.VSecurity;
import io.v.v23.verror.VException;

public class InMemoryFortuneServer implements FortuneServer {
    private final List<String> fortunes = new ArrayList<>();
    private final Random random = new Random(System.currentTimeMillis());

    @Override
    public String get(VContext ctx, ServerCall call) throws VException {
        if (fortunes.isEmpty()) {
            throw new VException("There are no fortunes available, try Add()ing one!");
        } else {
            return fortunes.get(random.nextInt(fortunes.size()));
        }
    }

    @Override
    public void add(VContext ctx, ServerCall call, String wisdom) throws VException {
        fortunes.add(wisdom);
    }

    public static Endpoint[] startServer() throws VException {
        // Initialize the Vanadium runtime and load its native shared library
        // implementation. This is required before we can do anything involving
        // Vanadium.
        VContext context = V.init();

        // Serve a new InMemoryFortuneServer with an allow-everyone authorizer.
        // This call will return immediately, serving is done in a separate
        // thread.
        Server fortuneServer = V.getServer(V.withNewServer(context, "",
            new InMemoryFortuneServer(),
            VSecurity.newAllowEveryoneAuthorizer()));

        return fortuneServer.getStatus().getEndpoints();
    }
}
EOF
```

And now let's create our entry point at
`src/main/java/io/v/tutorial/FortuneTutorial.java`:

<!-- @defineMainMethod @test -->
```
cat <<EOF > src/main/java/io/v/tutorial/FortuneTutorial.java
package io.v.tutorial;

import java.io.IOException;
import java.util.Arrays;

import io.v.v23.naming.Endpoint;
import io.v.v23.verror.VException;

public class FortuneTutorial {
    public static void main(String[] args) throws IOException, VException {
        Endpoint[] endpoints = InMemoryFortuneServer.startServer();
        System.out.println("FortuneServer available at the following endpoints: " +
                Arrays.toString(endpoints));
        System.out.println("Listening for connections, press enter to quit.");
        System.in.read();
        System.out.println("Exiting...");
    }
}
EOF
```

## Running the server

Now you are ready to build and run the server.

<!-- @buildWrapper @test -->
```
gradle installDist
```

This will leave an executable script in
`build/install/fortuneJava/bin/fortuneJava`. When we run it:

{{# helpers.code }}
FortuneServer available at the following endpoints: [@5@wsh@127.0.0.1:54221@50704f409f1fc0bf20f01020b02f2030@s@sjr@example.com-15180@@, @5@wsh@192.168.2.4:54221@50704f409f1fc0bf20f01020b02f2030@s@sjr@example.com-15180@@]
Listening for connections, press enter to quit.

{{/ helpers.code }}

Excellent, the server is now running. Let's write a client to talk to it.

## Defining a Fortune client

The VDL step has generated a client stub for us to use to call methods on a
server. We obtain stub instances from the generated `FortuneClientFactory`
class. The only other piece of information we need is the name of the [endpoint]
to which to talk.

Let's create `src/main/java/io/v/tutorial/FancyFortuneClient.java`:

<!-- @createClientDefinition @test -->
```
cat <<EOF > src/main/java/io/v/tutorial/FancyFortuneClient.java
package io.v.tutorial;

import io.v.v23.OptionDefs;
import io.v.v23.Options;
import io.v.v23.context.VContext;
import io.v.v23.verror.VException;

public class FancyFortuneClient {
    private final VContext context;
    private final FortuneClient client;
    private final Options options;

    public FancyFortuneClient(VContext context, String endpointName) {
        this.context = context;
        this.client = FortuneClientFactory.getFortuneClient(endpointName);

        // The SKIP_SERVER_ENDPOINT_AUTHORIZATION is necessary because this
        // tutorial does not deal with trust. If we omit this option, our client
        // will not trust the server. Your production code should not set this
        // option because it makes the client vulnerable to man-in-the-middle
        // attacks.
        this.options = new Options().set(OptionDefs.SKIP_SERVER_ENDPOINT_AUTHORIZATION,
                true);
    }

    public String get() throws VException {
        return client.get(context, options);
    }

    public void add(String wisdom) throws VException {
        client.add(context, wisdom, options);
    }
}
EOF
```

Let's modify the main FortuneTutorial class a little. It will now have three
modes depending on how many arguments we pass in:

  * no arguments: start a Fortune server just as we did in the first part of the
    tutorial

  * one argument: fetch a fortune from the endpoint named by that argument

  * two or more arguments: add the second and subsequent arguments as fortunes
    to the server named by the first argument

For example:

{{# helpers.code }}
build/install/fortuneJava/bin/fortuneJava  # run a server
build/install/fortuneJava/bin/fortuneJava @5@...@@  # fetch a fortune
build/install/fortuneJava/bin/fortuneJava @5@...@@ "Hello world!"  # add a fortune
{{/ helpers.code }}

Here is the new FortuneTutorial:

<!-- @refineMainMethod @test -->
```
cat <<EOF > src/main/java/io/v/tutorial/FortuneTutorial.java
package io.v.tutorial;

import java.io.IOException;
import java.util.Arrays;

import io.v.v23.V;
import io.v.v23.naming.Endpoint;
import io.v.v23.verror.VException;

public class FortuneTutorial {
    public static void main(String[] args) throws IOException, VException {
        if (args.length > 0) {
            FancyFortuneClient client = new FancyFortuneClient(V.init(), args[0]);
            if (args.length >= 2) {
                for (int i = 1; i < args.length; i++) {
                    client.add(args[i]);
                }
            } else {
                System.out.println(client.get());
            }
        } else {
            Endpoint[] endpoints = InMemoryFortuneServer.startServer();
            System.out.println("FortuneServer available at the following endpoints: " +
                    Arrays.toString(endpoints));
            System.out.println("Listening for connections, press enter to quit.");
            System.in.read();
            System.out.println("Exiting...");
        }
    }
}
EOF
```

Build the tutorial again:

<!-- @buildWrapper @test -->
```
gradle installDist
```

Here's an example session:

{{# helpers.code }}
$ FortuneServer available at the following endpoints: [@5@wsh@127.0.0.1:36191@c00090af3ff050d020ef3f4f4f40ffff@s@sjr@example.com-28934@@, @5@wsh@192.168.2.4:36191@c00090af3ff050d020ef3f4f4f40ffff@s@sjr@example.com-28934@@]
Listening for connections, press enter to quit.
{{/ helpers.code }}

In a separate terminal:

{{# helpers.code }}

$ export ENDPOINT=/@5@wsh@192.168.2.4:36191@c00090af3ff050d020ef3f4f4f40ffff@s@sjr@example.com-28934@@
$ build/install/fortuneJava/bin/fortuneJava $ENDPOINT
Exception in thread "main" io.v.v23.verror.VException: sjr:<rpc.Client>"/@5@wsh@192.168.2.4:36191@c00090af3ff050d020ef3f4f4f40ffff@s@sjr@example.com-28934@@".Get: Error: There are no fortunes available, try Add()ing one!
        at io.v.v23.verror.VExceptionVdlConverter.nativeFromVdlValue(VExceptionVdlConverter.java:70)
        at io.v.v23.verror.VExceptionVdlConverter.nativeFromVdlValue(VExceptionVdlConverter.java:22)
        at io.v.v23.vom.BinaryDecoder.readValue(BinaryDecoder.java:190)
        at io.v.v23.vom.BinaryDecoder.readValueMessage(BinaryDecoder.java:118)
        at io.v.v23.vom.BinaryDecoder.decodeValue(BinaryDecoder.java:85)
        at io.v.v23.vom.VomUtil.decode(VomUtil.java:104)
        at io.v.impl.google.rpc.ClientCallImpl.nativeFinish(Native Method)
        at io.v.impl.google.rpc.ClientCallImpl.finish(ClientCallImpl.java:35)
        at io.v.tutorial.FortuneClientImpl.get(FortuneClientImpl.java:62)
        at io.v.tutorial.FancyFortuneClient.get(FancyFortuneClient.java:21)
        at io.v.tutorial.FortuneTutorial.main(FortuneTutorial.java:19)
$ build/install/fortuneJava/bin/fortuneJava $ENDPOINT "Hello, world!"
$ build/install/fortuneJava/bin/fortuneJava $ENDPOINT
Hello, world!

{{/ helpers.code }}

{{# helpers.hidden }}
<!-- @deleteProjectDir @test -->
```
rm -Rf $JAVA_PROJECT_DIR
```
{{/ helpers.hidden }}

## Summary

Congratulations! You have successfully run the Java fortune example.

You have:
- Built a fortune client and server in Java.
- Established communication between the Java and Go clients and servers.
- Learned about using Vanadium in Java as compared to Go.

[client-server]: /tutorials/basics.html
[endpoint]: /glossary.html#endpoint
[gradle]: http://gradle.org/
[gradleinstall]: https://docs.gradle.org/current/userguide/installation.html
[name]: /glossary.html#object-name
[vdl]: /glossary.html#vanadium-definition-language-vdl-
