= yaml =
title: "Fortune in JS"
fullTitle: "Fortune in JavaScript"
layout: tutorial
wherein: you build a fortune teller service and a client to talk to it.
sort: 4
toc: true
prerequisites: {completer: js-fortune, scenario: e, also: {jsSpecial: true, chrome: true}}
= yaml =

## Introduction

This tutorial creates a fortune teller example in order to go more deeply into
some Vanadium concepts than [Hello Peer][hello-peer]. In addition, this
tutorial demonstrates how to connect
the application with a compatible Go-language fortune application.

JavaScript Vanadium applications are based around the same fundamental structure
as Go Vanadium applications. Because of the similarities, this tutorial
focuses on the differences between building Vanadium applications
in Go and JavaScript.

## Defining the Fortune service

In the [Hello Peer][hello-peer] tutorial, [VDL] (Vanadium Definition Language)
was not used.
It is possible to communicate without VDL for simple applications, but
it is strongly recommended to use VDL for cross-platform, cross-language,
or more complex applications. VDL provides a clear, strongly-typed definition
of the protocols that your clients and servers will use to communicate with each other.

When not using VDL, different programming languages may have different
representations of values that may not be coerced to compatible types.
In particular, a special representation is used for JavaScript values
when VDL is not being used that may be incompatible with Go values.

### Fortune VDL

We will reuse the same interface definition from the
[Client/Server Basics tutorial][client-server].
`$V_TUT/src/fortune/ifc/fortune.vdl` defines a fortune teller service, which
allows clients to `Get` and `Add` fortunes. The relevant code is reproduced below:

{{# helpers.code }}
package fortune

type Fortune interface {
  // Returns a random fortune.
  Get() (wisdom string | error)
  // Adds a fortune to the set used by Get().
  Add(wisdom string) error
}
{{/ helpers.code }}

The `vdl` tool generates a JavaScript file from this protocol definition.

<!-- @generateFortuneVDLJS @buildjs @test @testui @completer -->
```
mkdir -p $V_TUT/src/fortune
VDLROOT=$V23_RELEASE/src/v.io/v23/vdlroot \
    VDLPATH=$V_TUT/src \
    $V_BIN/vdl generate -lang=javascript -js-out-dir=$V_TUT/src \
    $V_TUT/src/fortune/ifc
```

When generating JavaScript, the flag `-js-out-dir` is used to specify where
generated files should appear.
After running this command, `$V_TUT/src/fortune/ifc/index.js`
should have been created.

### Implementation

The code below implements the Fortune service.
It defines the `Get` and `Add` methods and attaches the VDL-generated interface
description to the service's prototype chain.

Create `$V_TUT/src/fortune/service/index.js`.

<!-- @fortuneImplementation @buildjs @test @testui @completer -->
```
mkdir -p $V_TUT/src/fortune/service
cat - <<EOF >$V_TUT/src/fortune/service/index.js
var vdlFortune = require('../ifc');

module.exports = FortuneService;

// Define the fortune service.
function FortuneService() {
  this.fortunes = [
    'You will reach the heights of success.',
    'Conquer your fears or they will conquer you.',
    'Today is your lucky day!',
  ];
  this.numFortunesServed = 0;
}

// Add VDL service metadata and type information.
FortuneService.prototype = new vdlFortune.Fortune();

// Define the FortuneServiceMethod bodies.
FortuneService.prototype.add = function(ctx, serverCall, wisdom) {
  this.fortunes.push(wisdom);
}
FortuneService.prototype.get = function(ctx, serverCall) {
  this.numFortunesServed++;
  var fortuneIndex = Math.floor(Math.random() *
    this.fortunes.length);
  return this.fortunes[fortuneIndex];
};
EOF
```

This service implementation is analogous to Go's. It also exposes two fields,
`fortunes` and `numFortunesServed`, which will be used to make the fortune teller
more interactive.

## Fortune server

Two files are used to serve the Fortune service: the JavaScript file that
serves the service and an HTML page to display the server status.

### Server code

Use a Vanadium server to serve the Fortune service.

<!-- @fortuneServerJS @buildjs @test @testui @completer -->
```
mkdir -p $V_TUT/src/fortune/server
cat - <<EOF >$V_TUT/src/fortune/server/index.js
var vanadium = require('vanadium');
var FortuneService = require('../service');

// Define the Vanadium configuration for this app.
var config = {
  logLevel: vanadium.vlog.levels.INFO,
  appName: 'Fortune Server'
};

// Setup Vanadium and serve the Fortune service.
vanadium.init(config, function(err, runtime) {
  if (err) {
    return displayError(err);
  }
  runtime.on('crash', displayError);

  // Create and serve the Fortune service.
  var service = new FortuneService();
  var serviceName = getDefaultServiceName(runtime.accountName);
  runtime.newServer(serviceName, service, function(err) {
    if (err) {
      displayError(err);
    }
  });

  // Initialize the UI (see fortune-server.html).
  uiInit(service, serviceName);
});
function getDefaultServiceName(accountName) {
  var homeDir = accountName.replace(/^dev.v.io:u:/, 'users/').replace(vanadium.security.ChainSeparator.val, '/');
  return homeDir + '/tutorial/fortune';
}
EOF
```

The Fortune server works similarly to the one in the [Client/Server Basics tutorial][client-server].
The service implementation:
- Uses a VDL protocol to define the Fortune interface
- Creates and runs the Fortune service
- Uses the default authorizer
- Uses the default dispatcher

The following sections describe some **key differences** between the JavaScript
and Go APIs.

### Configuration

A configuration can optionally be specified when initializing Vanadium,
for example:

{{# helpers.code }}
var config = {
  logLevel: vanadium.vlog.levels.INFO,
  appName: 'Fortune Server'
};
{{/ helpers.code }}

This sets the output level for Vanadium log messages to `INFO` (`WARN` is the default)
and sets the name of the application, which is primarily used to identify the
application in error messages.

Similar parameters are typically specified through command line flags with Go.

### Serving at a name

The Fortune service was served using a Vanadium [name]. To learn more about names and name resolution, read
the [Naming Concepts][naming-concepts] page or go through the [Naming tutorial][naming-tutorial].

{{# helpers.code }}
// Serve the service at a Vanadium name.
server.serve(name, service, callback);
{{/ helpers.code }}

In the [Client/Server Basics tutorial][client-server], the Fortune client connected to the server directly using
a name rooted at its [endpoint address][endpoint].
In contrast, the server in this tutorial uses a name that does not include
an endpoint address and is resolved against a mount table.

### Server HTML

Create the HTML page. This page displays:
- The service name
- The number of fortunes sent by the service
- The service's list of fortunes

The service will manipulate the page as its data is updated.

<!-- @fortuneServerHTML @buildjs @test @testui @completer -->
```
cat - <<EOF >$V_TUT/fortune-server.html
<!DOCTYPE html>
<html>
<head>
  <title>Fortune Teller - Server</title>
  <script>
    // Helpers to display status information on the page.
    function displayError(err) {
      displayNumFortunesServed('Error: ' + err.toString());
    }
    function displayNumFortunesServed(count) {
      document.getElementById('fortune-count').innerHTML = count;
    }
    function displayFortunes(fortunes) {
      var fortuneList = document.getElementById('fortune-list');
      // Assume that only new fortunes can be added to the end list.
      for (var i = fortuneList.childNodes.length; i < fortunes.length; i++) {
        var bullet = document.createElement('li');
        bullet.textContent = fortunes[i];
        fortuneList.appendChild(bullet);
      }
    }
    function setServiceName(serviceName) {
      return document.getElementById('service-name').textContent = serviceName;
    }
    function uiInit(service, serviceName) {
      setServiceName(serviceName);
      setInterval(function() {
        displayNumFortunesServed(service.numFortunesServed);
        displayFortunes(service.fortunes);
      }, 250);
    }
  </script>
</head>
<body>
  <h1>Server</h1>
  <p>
    <span>Name of service to provide to clients: </span>
    <span id="service-name"></span>
  </p>
  <p>
    List of fortunes:
    <br><ol id="fortune-list"></ol></br>
  </p>
  <p>
    Total Fortunes Sent: <span id="fortune-count">0</span>
  </p>
  <script src="browser/fortune-server.js"></script>
</body>
</html>
EOF
```

## Fortune client

As with the server, the client consists of two files: a JavaScript file that
contains the application logic and an HTML page for the user interface.

### Client code

The client code starts Vanadium and waits for the user to act.
- Upon pressing the `Add` button, the client makes an `Add` RPC request.
- Upon pressing the `Get` button, the client makes a `Get` RPC request.

Create `$V_TUT/src/fortune/client/index.js`.

<!-- @fortuneClientJS @buildjs @test @testui @completer -->
```
mkdir -p $V_TUT/src/fortune/client
cat - <<EOF >$V_TUT/src/fortune/client/index.js
var vanadium = require('vanadium');

// Define the Vanadium configuration for this app.
var config = {
  logLevel: vanadium.vlog.levels.INFO,
  appName: 'Fortune Client'
};

vanadium.init(config, function(err, runtime) {
  if (err) {
    displayError(err);
    return;
  }

  // Get runtime context and client.
  var context = runtime.getContext();
  var client = runtime.getClient();

  // Set default service name.
  var defaultName = getDefaultServiceName(runtime.accountName);
  setServiceName(defaultName);

  // Listen for button presses.
  document.getElementById('get-button').addEventListener('click', getFortune);
  document.getElementById('add-button').addEventListener('click', addFortune);

  // Adds a fortune to the fortune teller.
  function addFortune() {
    updateStatus('Adding ' + getEnteredFortune() + '...');
    client.bindTo(context, getServiceName(), function(err, s) {
      if (err) {
        displayError(err);
        return;
      }

      s.add(context, getEnteredFortune(), function(err) {
        if (err) {
          displayError(err);
          return;
        }
        updateStatus('Done!');
      });
    });
  }

  // Gets a random fortune from the fortune teller.
  function getFortune() {
    updateStatus('Getting random fortune...');
    client.bindTo(context, getServiceName(), function(err, s) {
      if (err) {
        displayError(err);
        return;
      }

      s.get(context, function(err, randomFortune) {
        if (err) {
          displayError(err);
          return;
        }

        displayFortune(randomFortune);
        updateStatus('Done!');
      });
    });
  }
});
function getDefaultServiceName(accountName) {
  var homeDir = accountName.replace(/^dev.v.io:u:/, 'users/').replace(vanadium.security.ChainSeparator.val, '/');
  return homeDir + '/tutorial/fortune';
}
EOF
```

### Client HTML

Create the client's HTML page. This page contains:
- An input for selecting the server endpoint
- An input for adding new fortunes
- A button to get new fortunes
- A running list of fortunes received
- JavaScript code to manipulate these elements

<!-- @fortuneClientHTML @buildjs @test @testui @completer -->
```
cat - <<EOF >$V_TUT/fortune-client.html
<!DOCTYPE html>
<html>
<head>
  <title>Fortune Teller - Client</title>
  <script>
    // Helpers to update and introspect the HTML page.
    function getServiceName() {
      return document.getElementById('service-name').value;
    }
    function setServiceName(serviceName) {
      return document.getElementById('service-name').value = serviceName;
    }
    function getEnteredFortune() {
      return document.getElementById('add-text').value;
    }
    function displayFortune(fortune) {
      var fortuneNode = document.createElement('li');
      fortuneNode.textContent = fortune;
      document.getElementById('fortune-list').appendChild(fortuneNode);
    }
    function displayError(err) {
      updateStatus(err.toString());
    }
    function updateStatus(status) {
      document.getElementById('status').innerHTML = status;
    }
  </script>
</head>
<body>
  <h1>Client</h1>
  <p>Service to connect to: <input id="service-name" type="text" placeholder="Enter a service name" size="60" /></p>
  <p>
  Fortune to add: <input type="text" id="add-text" placeholder="write a custom fortune" size="60"/> <button id="add-button">Add Fortune</button>
  </p>
  <p><button id="get-button">Get Fortune</button></p>
  <h2>Status: <span id="status">Ready</span></h2>
  <p>Received fortunes: <ol id="fortune-list"></ol></p>
  <script src="browser/fortune-client.js"></script>
</body>
</html>
EOF
```

### About bindTo

The example above uses `bindTo` to retrieve a service stub. This step does not
exist when using Go.

{{# helpers.code }}
client.bindTo(context, name, callback);
{{/ helpers.code }}

`bindTo` retrieves the service definition from the remote server. This allows
the client to generate a service stub without needing a local VDL definition.
In contrast, Go clients typically get the service definition from the generated
VDL code because types must be known at compile-time.

If the JavaScript client already has access to the service signature, it can skip
the retrieval step by creating the stub directly using `bindWithSignature`:

{{# helpers.code }}
client.bindWithSignature(name, signature);
{{/ helpers.code }}


### About contexts

The `context` or `ctx` variable has appeared in a few places in this tutorial.

{{# helpers.code }}
// Client connecting to a service.
client.bindTo(context, serviceName, callback);

// Fortune service method definition.
FortuneService.prototype.get = function(ctx, serverCall) {
  ...
};
{{/ helpers.code }}

Contexts are used to:
- Configure deadlines and timeouts for RPCs
- Provide request traces when debugging
- Carry security configuration information during a request

When a service method is invoked, the context it receives should generally be
used for any ensuing outgoing RPCs so that the full sequence of calls can
be traced.

## Running Fortune

### Browserify

Use `browserify` to build the browser-targeted JavaScript files, which
integrate the Vanadium libraries with the server and client code.

<!-- @browserifyFortune @buildjs @test @testui @completer -->
```
NODE_PATH=$V_TUT $V_TUT/node_modules/.bin/browserify \
  $V_TUT/src/fortune/client/index.js -o $V_TUT/browser/fortune-client.js
NODE_PATH=$V_TUT $V_TUT/node_modules/.bin/browserify \
  $V_TUT/src/fortune/server/index.js -o $V_TUT/browser/fortune-server.js
```

### Combined HTML page

For demonstration purposes, the Fortune client and server are shown on the same page.

<!-- @fortuneIndexHTML @buildjs @test @testui @completer -->
```
cat - <<EOF >$V_TUT/fortune.html
<!DOCTYPE html>
<html>
<head>
  <title>Fortune Teller</title>
</head>
<body style="background: #000000;">
  <div style="position:fixed;top:0px;left:0px;bottom:0;width:48%; background: #ffffff;">
    <iframe id="client" src="fortune-client.html" style="width:100%; height:100%;" frameBorder="0"></iframe>
  </div>
  <div style="position:fixed;top:0px;right:0px;bottom:0;width:48%; background: #ffffff;">
    <iframe id="server" src="fortune-server.html" style="width:100%; height:100%;" frameBorder="0"></iframe>
  </div>
</body>
</html>
EOF
```

### Try it out

You are ready to serve the web pages on a local server. Run the web server on port 8989.

Using node-static, the command is:

<!-- @nodeStaticBackground @test @testui @sleep -->
```
$V_TUT/node_modules/.bin/static $V_TUT -p 8989 > /dev/null &
TUT_PID_HTTPD=$!
```

This static server runs in the background and is stopped in the [Cleanup section].

Go to http://127.0.0.1:8989/fortune.html to view the examples.

{{# helpers.hidden }}
Check that curling the fortune page doesn't fail. Since the user presumably
visits the link above, this ensures that the URL functions properly.

<!-- @curlFortune @test @testui -->
```
curl -f http://127.0.0.1:8989/fortune.html &> /dev/null
```

Set the workspace, if necessary. Check other required environment variables.

<!-- @mavenEnv @testui -->
```
# Set WORKSPACE, if not chosen.
[ -z "$WORKSPACE" ] && export WORKSPACE=${JIRI_ROOT}/www

# Check that the environment variables exist.
echo ${CHROME_WEBDRIVER?} > /dev/null
echo ${GOOGLE_BOT_USERNAME?} > /dev/null
echo ${GOOGLE_BOT_PASSWORD?} > /dev/null
```

Then, run the WebDriver test with maven.

<!-- @mavenTest @testui -->
```
# Run the maven test.
TMPDIR=/tmp xvfb-run -s '-ac -screen 0 1024x768x24' \
  mvn test \
  -f=$JIRI_ROOT/www/test/ui/pom.xml \
  -Dtest=FortuneUITest \
  -DchromeDriverBin=$CHROME_WEBDRIVER \
  -DhtmlReportsRelativePath=htmlReports \
  -DgoogleBotUsername=$GOOGLE_BOT_USERNAME \
  -DgoogleBotPassword=$GOOGLE_BOT_PASSWORD \
  -DprincipalBin=$V_BIN/principal \
  -DtutDir=$V_TUT
```
{{/ helpers.hidden }}

## Interoperating with Go

The client and server defined here can communicate with the client and server that was defined in Go.

### Creating an OAuth-authenticated principal for Go

For simplicity, this example uses the default authorizer. To pass
the authorization check, it is possible to create a principal with
the proper blessings for communication with the browser. To read more, go to
the [Security Concepts] page or run through the [Principals and blessings] tutorial.

Use the `principal` tool, as follows:

```
$V_BIN/principal --v23.credentials $V_TUT/cred/basics \
  seekblessings
```

A new tab will appear in the browser. Click the `Bless` button. The Go code
will now have access to an OAuth-authenticated blessing that matches the
browser's.

In general, it is not necessary to generate an identical set of blessings; other
authorizers can be used to grant access with different rules than the default
authorizer.

### Go client + JS server

In order for the Go client to contact the JavaScript server, it needs the
Vanadium name for the server.

`$JS_FORTUNE_NAME` will hold the name of the JavaScript server. The following
command parses the principal and computes the name of the fortune server.
It should match the service name listed on the Fortune page.

```
export JS_FORTUNE_NAME=$(
  $V23_RELEASE/bin/principal get \
    --v23.credentials $V_TUT/cred/basics default \
    | $V_BIN/principal dumpblessings - \
    | awk -F/ '/Blessings/ {print "users/" $3 "/chrome/tutorial/fortune"}'
  )
```

Use the Go fortune client to request a fortune from the JS server.
```
$V_TUT/bin/client --v23.credentials $V_TUT/cred/basics \
  --server $JS_FORTUNE_NAME
```

It is also possible to add a fortune:

```
$V_TUT/bin/client --v23.credentials $V_TUT/cred/basics \
  --server $JS_FORTUNE_NAME -add 'Fortune favors the bold.'
```

### Go server + JS client

To use a Go fortune server with a JS client, first run the server.

<!-- @runFortuneGoServer @test @testui @sleep -->
```
kill_tut_process TUT_PID_SERVER
$V_TUT/bin/server --v23.credentials $V_TUT/cred/basics \
  --endpoint-file-name=$V_TUT/server.txt &
TUT_PID_SERVER=$!
```

The server's endpoint will be used to identify the fortune service. To get
the endpoint, run the following command.

<!-- @runFortuneGoServer -->
```
cat $V_TUT/server.txt # The go server's endpoint address
```

The Go server's endpoint should be printed out to the console.
**Copy this endpoint and paste it into the client page's Server field.**

The JS client will now be able to call `Get` and `Add` on the Go server.

## Cleanup

Once finished, stop the HTTP server and the Go fortune server.

<!-- @runFortuneGoServer @test @testui -->
```
kill $TUT_PID_HTTPD
kill $TUT_PID_SERVER
```

## Summary

Congratulations! You have successfully run the Go-JS fortune example.

You have:
- Built a fortune client and server in JavaScript. A hosted copy of the tutorial
result can be accessed [here][built-example].
- Established communication between the JavaScript and Go clients and servers.
- Learned about using Vanadium in JavaScript as compared to Go.

[vdl]: /glossary.html#vanadium-definition-language-vdl-
[client-server-terminology]: /tutorials/basics.html#terminology
[client-server]: /tutorials/basics.html
[built-example]: /tutorials/javascript/results/fortune.html
[hello-peer]: /tutorials/javascript/hellopeer.html
[default-auth]: /tutorials/security/principals-and-blessings.html#default-authorization-policy
[endpoint]: /glossary.html#endpoint
[name]: /glossary.html#object-name
[naming-concepts]: /concepts/naming.html
[naming-tutorial]: /tutorials/naming/
[Security Concepts]: /concepts/security.html
[Principals and blessings]: /tutorials/security/principals-and-blessings.html
[Cleanup section]: #cleanup
