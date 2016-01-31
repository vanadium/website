= yaml =
title: Hello Peer
layout: tutorial
wherein: Vanadium says hello in a peer-to-peer manner.
prerequisites: {completer: js-hellopeer}
sort: 2
toc: true
= yaml =

## Introduction

This tutorial demonstrates how to use JavaScript to create a peer-to-peer
Vanadium app and run it in your browser.

## Setup

Vanadium has two core dependencies when building browser apps:

* [Node.js][node] for running a JavaScript-based build system.
Download and install node from [https://nodejs.org/download][node] and add it to your `PATH`.
* [Go][golang] for core Vanadium tools. This is technically optional for this tutorial, but
will be used in later tutorials. Download and install it from https://golang.org/dl/ or
through your package manager and make sure it is in your `PATH`.

Apart from these two global dependencies, the remainder of the setup
involves only local changes to the project directory.

### Project directory

First, create a directory for the tutorial. The environment variable
`$V_TUT` will be used throughout the tutorials to represent this directory.

<!-- @createProjectDir @buildjs @test @testui @completer -->
```
export V_TUT=${V_TUT-$HOME/v23_tutorial}
mkdir -p $V_TUT
```

### Install Node modules with NPM

The Node Package Manager `npm` (which was installed with Node.js)
is used to install the modules
needed for the tutorial to `$V_TUT/node_modules`:

```
cd $V_TUT
echo "{}" > $V_TUT/package.json
npm install vanadium browserify node-static
```

{{# helpers.hidden }}
The following block should be removed once vanadium is available on npm.
{{/ helpers.hidden }}
{{# helpers.warning }}
**Pre-release only: Run this command block instead.**

<!-- @removeThisBlockBeforeRelease @buildjs @test @testui @completer -->
```
cd $V_TUT
echo "{}" > $V_TUT/package.json
npm install git+https://vanadium.googlesource.com/release.js.core
npm install browserify node-static
```
{{/ helpers.warning }}

After running this command, the following modules will be installed:

* `vanadium` - The core vanadium library.
* `browserify` - A build tool used to create a browser-compatible
JavaScript file from a project structured for node. Vanadium uses node to handle
JavaScript dependency management.
* `node-static` - A simple static web server that enables the tutorials
to be viewed in a browser.


### Vanadium Chrome extension

Vanadium currently requires an extension to run JavaScript in the browser.
This extension is used to securely store credentials and
additionally contains Vanadium's go-language core.
The Vanadium team is working to remove the Chrome-extension dependency
in the future.

The extension can be installed from its page on the Chrome web store:
https://chrome.google.com/webstore/detail/jcaelnibllfoobpedofhlaobfcoknpap
.

For more information, see: [Vanadium Chrome extension Overview](/tools/vanadium-chrome-extension.html)

**You have finished setting up your project. Now, onto the code!**

## Creating a Vanadium application

Each **peer** in the application will consist of a **server** and a **client**.
After receiving a request, the server outputs the message sent by the client.

The following sections break down the application code into bite-sized snippets.
**The full file will be shown afterwards.**

### Service definition

Define a service that has a single method `hello()` with a single
parameter `greeting`, in addition to the required `context` and `serverCall` parameters.

{{# helpers.code }}
function HelloService() {}

HelloService.prototype.hello = function(ctx, serverCall, greeting) {
  displayHello(greeting);
};
{{/ helpers.code }}

It is also possible to define service interfaces in [VDL] (Vanadium Definition
Language) in order to declare the
protocol with explicit type information.
This is demonstrated in the next tutorial.

### Creating the service

The service is created and served by calling `runtime.newServer` and passing in
the name used to mount the service, along with the service itself.

{{# helpers.code }}
runtime.newServer(serviceName, new HelloService(), function callback() {
  // HelloService is now ready.
});
{{/ helpers.code }}

### Calling the service from a client

To call a service, first bind on the name. This results in a stub object
that represents the service.
When the client program calls a method on the stub,
the corresponding method is remotely invoked on the service.


{{# helpers.code }}
var client = runtime.getClient();
var ctx = runtime.getContext();

client.bindTo(ctx, serviceName, function(err, helloService) {
  if (err) {
    // handle err
  }

  var greeting = 'Hello Vanadium';
  helloService.hello(ctx, greeting, function callback(err) {
    if (err) {
      // handle err
    }
    // The call is complete!
  });
});
{{/ helpers.code }}

### Putting it all together

This example combines the service, server, and client into a single file.
Typically, the client is a separate program from the server and service.

The following command creates the peer implementation `$V_TUT/src/hello/peer.js`.

<!-- @helloPeerJS @buildjs @test @testui @completer -->
```
mkdir -p $V_TUT/src/hello
cat - <<EOF >$V_TUT/src/hello/peer.js
var vanadium = require('vanadium');

// Define HelloService and the hello() method.
function HelloService() {}

HelloService.prototype.hello = function(ctx, serverCall, greeting) {
  displayHello(greeting);
};

// Initialize Vanadium runtime.
vanadium.init(function(err, runtime) {
  if (err) {
    showStatus('Initialization error: ' + err);
    return;
  }
  showStatus('Initialized');
  runtime.on('crash', function(err) {
    showStatus('The runtime has crashed unexpectedly and the page must be reloaded.');
  });

  setupServer(runtime);
  setupClient(runtime);
});

// Setup the server.
function setupServer(runtime) {
  // Create a server and serve the HelloService.
  var serviceName = getLocalPeerName(runtime.accountName);
  runtime.newServer(serviceName, new HelloService(), function(err) {
    if (err) {
      showServerStatus('Failed to serve ' + serviceName + ': ' + err);
      return;
    }
    showServerStatus('Serving');
    // HelloService is now served.
  });
}

// Setup the client.
function setupClient(runtime) {
  // Create a client and bind to the service.
  var client = runtime.getClient();
  var ctx = runtime.getContext();

  var serviceName = getRemotePeerName(runtime.accountName);
  showClientStatus('Binding');
  client.bindTo(ctx, serviceName, function(err, helloService) {
    if (err) {
      showClientStatus('Failed to bind to ' + serviceName + ': ' + err);
      return;
    }
    showClientStatus('Ready');

    registerButtonHandler(function(greeting) {
      showClientStatus('Calling');
      // Call hello() on the service.
      helloService.hello(ctx, greeting, function(err) {
        if (err) {
          showClientStatus('Error invoking hello(): ' + err);
          return;
        }
        showClientStatus('Ready');
      });
    });
  });
}

// Get the local and remote names.
function getLocalPeerName(accountName) {
  var homeDir = accountName.replace(/^dev.v.io:u:/, 'users/').replace(vanadium.security.ChainSeparator.val, '/');
  var hash = window.location.hash;
  return homeDir + '/tutorial/hello' + hash;
}
function getRemotePeerName(accountName) {
  var localPeer = getLocalPeerName(accountName);
  var splitPeer = localPeer.split('#');
  if (splitPeer[1] == 'A') {
    splitPeer[1] = 'B';
  } else {
    splitPeer[1] = 'A';
  }
  return splitPeer.join('#');
}

// Manipulate the html page.
function displayHello(greeting) {
  var li = document.createElement('li');
  li.textContent = greeting;
  document.getElementById('receivedhellos').appendChild(li);
}
function registerButtonHandler(fn) {
  document.getElementById('hellobutton').addEventListener('click', function() {
    var greeting = document.getElementById('hellotext').value;
    fn(greeting);
  });
}
function showClientStatus(text) {
  document.getElementById('clientstatus').textContent = text;
}
function showServerStatus(text) {
  document.getElementById('serverstatus').textContent = text;
}
function showStatus(text) {
  showClientStatus(text);
  showServerStatus(text);
}
EOF
```

### Building for the browser

Use `browserify` to build the browser-targeted JavaScript file, which
combines `peer.js` above with its dependencies, such as the Vanadium library:

<!-- @browserifyServer @buildjs @test @testui @completer -->
```
mkdir -p $V_TUT/browser
NODE_PATH=$V_TUT $V_TUT/node_modules/.bin/browserify \
  $V_TUT/src/hello/peer.js -o $V_TUT/browser/hello-peer.js
```

This command generates `$V_TUT/browser/hello-peer.js`.

### Adding the script to an HTML page

Finally, a web page is needed to host `peer.js`.

Create another HTML file in `$V_TUT/browser/peer.html` that includes the server
JavaScript code and links to the client.

<!-- @helloPeerHTML @buildjs @test @testui @completer -->
```
cat - <<EOF >$V_TUT/browser/peer.html
 <!DOCTYPE html>
 <html>
 <head>
   <title>Hello Peer</title>
 </head>
 <body>
   <div>
     <div style="float:left;"><input id="hellotext" value="Hello World"></input><button id="hellobutton">Send</button></div>
     <div style="float:right; white-space:nowrap">
     <div>Client Status: <span id="clientstatus">Initializing</span></div>
     <div>Server Status: <span id="serverstatus">Initializing</span></div>
     </div>
   </div>
   <div style="clear:both;">
     Received Greetings:
     <ol id="receivedhellos"></ol>
   </div>
   <script src="hello-peer.js"></script>
 </body>
 </html>
EOF
```

Create an HTML file in `$V_TUT/hello.html` that contains two copies of `peer.js`
in iframes for simplified viewing.

<!-- @helloMainHTML @buildjs @test @testui @completer -->
```
cat - <<EOF >$V_TUT/hello.html
 <!DOCTYPE html>
 <html>
 <head>
   <title>Hello Peers</title>
 </head>
 <body style="background: #000000;">
   <div style="position:fixed;top:0px;left:0px;bottom:0px;width:48%; background: #ffffff;">
     <iframe id="frameA" src="browser/peer.html#A" style="width:100%; height:100%;" frameBorder="0"></iframe>
   </div>
   <div style="position:fixed;top:0px;right:0px;bottom:0px;width:48%; background: #ffffff;">
     <iframe id="frameB" src="browser/peer.html#B" style="width:100%; height:100%;" frameBorder="0"></iframe>
   </div>
 </body>
 </html>

EOF
```

**You are now ready to view the peers in a browser!**

## Viewing in a browser

### Starting a local server

You are ready to serve the web pages on a local server. Run the web server on port 8989.

Using node-static, the command is:

```
$V_TUT/node_modules/.bin/static $V_TUT -p 8989 > /dev/null
```

{{# helpers.hidden }}
For the test, we want to run the node-static server without blocking. It's not
worth adding a cleanup step to the tutorial, so it's done in this hidden block.

<!-- @serveHello @test @testui @sleep -->
```
$V_TUT/node_modules/.bin/static $V_TUT -p 8989 > /dev/null &
TUT_PID_HTTPD=$!
```

Curl the page to confirm its existence.
<!-- @curlHello @test @testui -->
```
curl -f http://127.0.0.1:8989/hello.html > /dev/null
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
  -Dtest=HelloPeerUITest \
  -DchromeDriverBin=$CHROME_WEBDRIVER \
  -DhtmlReportsRelativePath=htmlReports \
  -DgoogleBotUsername=$GOOGLE_BOT_USERNAME \
  -DgoogleBotPassword=$GOOGLE_BOT_PASSWORD
```

And clean up the static server.

<!-- @cleanupHTTPD @test @testui -->
```
kill $TUT_PID_HTTPD
```

{{/ helpers.hidden }}

### Viewing the pages

The page shows two peers. Enter a greeting (or use the default 'Hello World') and
press Send for one peer. The other peer will receive the greeting.

{{# helpers.warning }}
On your first visit to a Vanadium web app, the Chrome Vanadium extension
prompts you to `Allow` blessings.
This grants the web app permission to use your identity when running servers and clients.

For the purposes of the tutorials, please click the `Allow` button when prompted
(this might be in another browser tab).
{{/ helpers.warning }}

Open http://127.0.0.1:8989/hello.html and allow the blessing.

## Summary

This tutorial demonstrated how to:
* Set up the Vanadium environment for JavaScript.
* Create and build a Hello Peer client and server.
* Run the example in a web browser. A hosted copy of the tutorial
result can be accessed [here][built-example].

[vdl]: /glossary.html#vanadium-definition-language-vdl-
[built-example]: /tutorials/javascript/results/hello.html
[node]: https://nodejs.org/download
[golang]: http://golang.org
