= yaml =
title: "Security in JS"
fullTitle: "Security in JavaScript"
layout: tutorial
wherein: you learn how to bless and authorize users in JavaScript
sort: 5
toc: true
prerequisites: {scenario: e, also: {jsSpecial: true, chrome: true}}
= yaml =

## Introduction
In the Fortune tutorial, you saw how to create a client and a server and how to
fetch fortunes from the server. However, the server and the client had
the same identity, which simplified authorization.

This tutorial demonstrates how to restrict calls to methods with a more
sophisticated authorization scheme. This tutorial does not explain the core
security concepts in much depth, so it is highly recommended that the
[Security Tutorials] are completed before starting.

### The return of Alice, Bob, Carol and Diane
The scenario and roles from the [Security Tutorials] will be replicated here:

* Alice hosts a fortune service and has blessings `alice`
* Bob is a friend of Alice (friends can get fortunes, but not add them) and
has blessings `alice:friends:bob`.
* Carol is a family member of Alice (family can both add and get fortunes) and
has blessings `alice:family:sister`.
* Diane is given blessings by Carol with an expiry caveat so until the
expiration takes effect Diane can act as a family member of Carol through
the blessings `alice:family:sister:guest:diane`.

However, there are a few modifications for the JavaScript tutorials. In
addition to the blessings above, each person with have an additional blessing
from OAuth. This will often be used as a trusted root for confirming the
identity of the other person.

### Sending blessings
The [Security Tutorials] passed the blessings and Alice's public key out of
band. In this tutorial, they will be sent between peers using the OAuth-blessing
as a trusted root to verify the identity of the corresponding peer.

Two main techniques will be explored for sending blessings:
* Running a service that returns the appropriate blessing given a request.
This is used to give Bob and Carol their blessings.
* Using a granter in a call to a service. Granters make it possible to specify
blessings on client calls. They are similar to passing in an argument, but
get access to the remote end's blessings which make it possible to create
a blessing for the remote public key. This is used when Carol provides a
blessing to Alice.

## Interfaces

First, define the VDL interfaces. In this tutorial, Alice hosts both a Fortune
service and a Blessing Provider service. The corresponding interfaces are shown
below.

### Fortune VDL

The Fortune VDL definition is nearly the same as in other tutorials, but includes
access tags. Fortune's `Get` method requires Read access, while `Add` requires
Write access.

This command creates `src/security/ifc/fortune.vdl`
```
mkdir -p $V_TUT/src/security/ifc
cat - <<EOF >$V_TUT/src/security/ifc/fortune.vdl
package security

import "v.io/v23/security/access"

type Fortune interface {
  // Returns a random fortune.
  Get() (wisdom string | error) {access.Read}
  // Adds a fortune to the set used by Get().
  Add(wisdom string) error {access.Write}
}
EOF
```

These security tags are used by the Permissions Authorizer, defined in the
[Permissions Authorizer tutorial].

### ProvideBlessings VDL

Alice also runs a ProvideBlessings service, which allows any client to make the
`GetBlessings` RPC. On each request, the method prompts Alice to decide whether to
return a blessing or an error. This service will be used to provide blessings to
Bob and Carol.

The following goes in `src/security/ifc/provide-blessings.vdl`
```
cat - <<EOF >$V_TUT/src/security/ifc/provide-blessings.vdl
package security

import "v.io/v23/security"

type ProvideBlessings interface {
  GetBlessings() (security.WireBlessings | error)
}
EOF
```

### Building VDL

Use the VDL tool to build these interfaces. The command will generate
`src/security/ifc/index.js`.

```
VDLROOT=$V23_RELEASE/src/v.io/v23/vdlroot \
    VDLPATH=$V23_RELEASE/src:$V_TUT/src \
    $V_BIN/vdl generate -lang=javascript -js-out-dir=$V_TUT/src \
    $V_TUT/src/security/ifc/...
```

## Vanadium security in JavaScript

### Alice

Alice runs two services in this example, a Fortune-teller service and a service
that provides blessings to callers.

#### Fortune service

**What follows is a copy of the Fortune implementation from the [Fortune tutorial].**

The access rules defined in VDL apply to this service despite no change to the
service body because the Fortune Service adds the VDL interface definition to its
prototype chain.

This command creates `src/security/service/fortune.js`
```
mkdir -p $V_TUT/src/security/service
cat - <<EOF >$V_TUT/src/security/service/fortune.js
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
FortuneService.prototype.add = function(ctx, serverCall, Fortune) {
  this.fortunes.push(Fortune);
}
FortuneService.prototype.get = function(ctx, serverCall) {
  this.numFortunesServed++;
  var fortuneIndex = Math.floor(Math.random() *
    this.fortunes.length);
  return this.fortunes[fortuneIndex];
};
EOF
```

#### Blessings service

This command creates `src/security/service/provide-blessings.js`
```
mkdir -p $V_TUT/src/security/service
cat - <<EOF >$V_TUT/src/security/service/provide-blessings.js
var vanadium = require('vanadium');
var vdlProvideBlessings = require('../ifc');

module.exports = ProvideBlessingsService;

// Define the provide blessings service, which allows clients to request blessings.
function ProvideBlessingsService(principal, getBlessingsCallback) {
  this._principal = principal;
  this._getBlessingsCallback = getBlessingsCallback;
}

// Add VDL service metadata and type information.
ProvideBlessingsService.prototype = new vdlProvideBlessings.ProvideBlessings();

// getBlessings handles requests for blessings and prompts the user for a
// blessing string to bless the client with. The user can deny the request.
ProvideBlessingsService.prototype.getBlessings = function(ctx, serverCall) {
  var desiredSuffix =
    this._getBlessingsCallback(serverCall.securityCall.remoteBlessingStrings);
  if (desiredSuffix === null) {
    return Promise.reject(new Error('No blessing provided - not authorized'));
  }
  var forPeerArgs = [ctx].concat(serverCall.securityCall.remoteBlessingStrings);

  var self = this;
  return this._principal.blessingStore.forPeer.apply(
    this._principal.blessingStore, forPeerArgs)
  .then(function(peerBlessings) {
    var expiryTime = new Date();
    expiryTime.setDate(new Date().getDate() + 1); // Expires in 1 day.
    var expiryCaveat = vanadium.security.createExpiryCaveat(expiryTime);
    return self._principal.bless(ctx, serverCall.securityCall.remoteBlessings.publicKey, peerBlessings, desiredSuffix, expiryCaveat);
  });
};
EOF
```

This service takes a principal and a callback function. When a client calls
getBlessings, Alice will use this callback to determine whether or not the
client truly ought to be blessed. Alice can also decide what name to use when
blessing the client.

#### Blessing store

It is helpful to inspect the blessing store of Alice, Bob, Carol, and Diane. The
following code block creates `src/security/lib/show-blessing-store.js`, which
(assuming some DOM elements) exposes the list of blessings that each user owns.

```
mkdir -p $V_TUT/src/security/lib
cat - <<EOF >$V_TUT/src/security/lib/show-blessing-store.js
module.exports = showBlessingStore;

function showBlessingStore(runtime) {
  var ctx = runtime.getContext();

  runtime.principal.blessingStore.getDefault(ctx)
  .then(function(defaultBlessings) {
    document.getElementById('default-blessings').textContent = defaultBlessings.toString();
  }).catch(function(err) {
    throw new Error('Error displaying default blessings: ' + err);
  });

  runtime.principal.blessingStore.getPeerBlessings(ctx)
  .then(function(peerBlessings) {
    var ul = document.getElementById('peer-blessings');

    // Remove all children in the list.
    while (ul.lastChild) {
      ul.removeChild(ul.lastChild);
    }

    // Add all the peerBlessings to the list.
    peerBlessings.forEach(function(blessings, pattern) {
      var item = document.createElement('li');
      item.textContent = pattern + ' -> ' + blessings.toString();
      ul.appendChild(item);
    });
  }).catch(function(err) {
    throw new Error('Error displaying peer blessings: ' + err);
  });
}
EOF
```

#### Alice code

The following goes in `src/security/alice.js`
```
mkdir -p $V_TUT/src/security
cat - <<EOF >$V_TUT/src/security/alice.js
var vanadium = require('vanadium');
var FortuneService = require('./service/fortune');
var ProvideBlessingsService = require('./service/provide-blessings');
var showBlessingStore = require('./lib/show-blessing-store');

var config = {
  logLevel: vanadium.vlog.levels.INFO,
};

vanadium.init(config, function(err, runtime) {
  if (err) {
    setStatus('Initialization error: ' + err);
    return;
  }
  runtime.on('crash', function(err) {
    setStatus('The runtime has crashed unexpectedly and the page must be reloaded.');
  });

  var aliceName = runtime.accountName.replace(/^dev.v.io:u:/, 'users/').replace(vanadium.security.ChainSeparator.val, '/') + // is this needed
    '/tutorial/alice';
  var aliceReqName = runtime.accountName.replace(/^dev.v.io:u:/, 'users/').replace(vanadium.security.ChainSeparator.val, '/') + // is this needed
    '/tutorial/alicerequest';

  var ctx = runtime.getContext();

  setStatus('Configuring blessings');
  var aliceBlessings;
  runtime.principal.blessSelf(ctx, 'alice', vanadium.security.unconstrainedUse)
  .then(function(blessings) {
    aliceBlessings = blessings;
    return runtime.principal.addToRoots(ctx, aliceBlessings);
  }).then(function() {
    return runtime.principal.blessingStore.set(ctx, aliceBlessings, '...');
  }).then(function(oldBlessings) {
    return runtime.principal.blessingStore.set(ctx, oldBlessings,
      'dev.v.io/role/vprod');
  }).then(function() {
    return runtime.principal.blessingStore.getDefault(ctx);
  }).then(function(oldDefault) {
    return runtime.principal.blessingStore.setDefault(ctx, vanadium.security.unionOfBlessings(ctx, oldDefault, aliceBlessings));
  }).then(function() {
    showBlessingStore(runtime);
    setStatus('Preparing to serve...');
    var fortuneServeConfig = {
      authorizer: createFortuneAuthorizer()
    };
    var fortuneService = new FortuneService();
    setInterval(function() {
      displayNumFortunesServed(fortuneService.numFortunesServed);
      displayFortunes(fortuneService.fortunes);
    }, 250);
    return runtime.newServer(aliceName, fortuneService,
      fortuneServeConfig);
  }).then(function() {
    var provideBlessingsConfig = {
      authorizer: function() {}
    };
    return runtime.newServer(
      aliceReqName,
      new ProvideBlessingsService(runtime.principal, askUserForBlessings),
      provideBlessingsConfig
    );
  }).then(function() {
    setStatus('Ready');
  }).catch(function(err) {
    setStatus('Error: ' + error);
  });
});

function createFortuneAuthorizer() {
  // ACLs
  var acl = new Map();
  var access = vanadium.security.access;
  acl.set(access.Read, {
    in: ['alice:family', 'alice:friends']
  });
  acl.set(access.Write, {
    in: ['alice:family']
  });
  return new access.permissionsAuthorizer(acl, access.Tag);
}

function setStatus(status) {
  document.getElementById('status').textContent = status;
}
function askUserForBlessings(blessings) {
  // Tutorial-only: If the blessings comes from Bob (19102) or Carol (19103),
  // helpfully suggest the correct suffix to bless them with.
  var suggestion = '';
  if (blessings[0].indexOf('19102') !== -1) {
    suggestion = 'friends:bob';
  } else if (blessings[0].indexOf('19103') !== -1) {
    suggestion = 'family:sister';
  }
  return window.prompt(
    'Received blessing request from peer with remote blessings: ' +
    blessings + '\nWhat blessing suffix should peer be given?',
    suggestion);
}
function displayFortunes(fortunes) {
  var fortuneList = document.getElementById('fortune-list');
  fortuneList.innerHTML = '';
  for (var i = 0; i < fortunes.length; i++) {
    var bullet = document.createElement('li');
    bullet.textContent = fortunes[i];
    fortuneList.appendChild(bullet);
  }
}
function displayNumFortunesServed(count) {
  document.getElementById('fortune-count').innerHTML = count;
}
EOF
```

#### Alice HTML

Alice's JavaScript is hosted in a corresponding HTML file:
```
cat - <<EOF >$V_TUT/browser/alice.html
<!DOCTYPE html>
<html>
<head>
  <title>Security - Alice</title>
</head>
<body>
  <br><h2>Alice</h2></br>
  <br>Default Blessings: <span id="default-blessings">----</span></br>
  <br><b>Peer Blessings:</b></br>
  <br><ul id="peer-blessings"></ul></br>
  <br>Status: <span id="status">Initializing...</span></br>
  <br></br>
  <div>
    <br>Current Fortunes:</br>
    <br><ul id="fortune-list"></ul></br>
  </div>
  <br>Fortunes Served: <span id="fortune-count">0</span></br>
  <script src="security-alice.js"></script>
</body>
</html>
EOF
```

### Bob
Bob is a friend of Alice and will be given a `alice:friends:bob` blessing that
enables read-only access to fortunes. In order to get this blessing, he needs
to contact Alice's blessing granter service.

#### Fortune client

This is the generic Fortune client that Bob, Carol, and Diane will use upon
connecting to Alice's Fortune server. The following command creates
`src/security/lib/fortune-client.js`.

```
mkdir -p $V_TUT/src/security/lib
cat - <<EOF >$V_TUT/src/security/lib/fortune-client.js
module.exports = {
  prepareClient: prepareClient,
  setStatus: setStatus,
  showFortune: showFortune
};

function prepareClient(ctx, alice) {
  onGetFortune(function() {
    setStatus('Getting a fortune...');
    alice.get(ctx)
    .then(function(f) {
      showFortune(f);
      setStatus('Ready');
    })
    .catch(function(err) {
      setStatus('Error in get(): ' + err);
    });
  });
  onAddFortune(function(fortuneToAdd) {
    setStatus('Adding a fortune...');
    alice.add(ctx, fortuneToAdd)
    .then(function() {
      setStatus('Ready');
    })
    .catch(function(err) {
      setStatus('Error in add(): ' + err);
    });
  });
}

function setStatus(status) {
  document.getElementById('status').textContent = status;
}
function showFortune(fortune) {
  document.getElementById('last-fortune').textContent = fortune;
}
function onGetFortune(cb) {
  document.getElementById('get-fortune').addEventListener('click', cb);
}
function onAddFortune(cb) {
  document.getElementById('add-fortune').addEventListener('click', function() {
    var fortuneToAdd = document.getElementById('fortune-to-add').value;
    cb(fortuneToAdd);
  });
}
EOF
```

#### Bob code

Bob should exist in `src/security/bob.js`:
```
cat - <<EOF >$V_TUT/src/security/bob.js
var vanadium = require('vanadium');
var showBlessingStore = require('./lib/show-blessing-store');
var clientLib = require('./lib/fortune-client');

var config = {
  logLevel: vanadium.vlog.levels.INFO
};

// Initialize Vanadium runtime
vanadium.init(config, function(err, runtime) {
  if (err) {
    throw new Error('Initialization error: ' + err);
  }
  runtime.on('crash', function(err) {
      throw new Error('The runtime has crashed unexpectedly and the page must be reloaded.');
  });

  showBlessingStore(runtime);

  clientLib.setStatus('Waiting for Alice\'s blessings...');
  var aliceReqName = runtime.accountName.replace(/^dev.v.io:u:/, 'users/').replace(vanadium.security.ChainSeparator.val, '/') + // is this needed
    '/tutorial/alicerequest';
  var aliceName = runtime.accountName.replace(/^dev.v.io:u:/, 'users/').replace(vanadium.security.ChainSeparator.val, '/') + // is this needed
    '/tutorial/alice';
  var ctx = runtime.getContext();
  var client = runtime.getClient();
  client.bindTo(ctx, aliceReqName)
  .then(function(req) {
    var callOpts = client.callOption({
      allowedServersPolicy: [runtime.accountName + '/http%3A%2F%2F127.0.0.1%3A19101']
    });
    return req.getBlessings(ctx, callOpts);
  }).then(function(blessings) {
    return runtime.principal.addToRoots(ctx, blessings)
    .then(function() {
      return runtime.principal.blessingStore.set(ctx, blessings, 'alice');
    });
  }).then(function() {
    showBlessingStore(runtime);
    clientLib.setStatus('Connecting to Alice...');
    return client.bindTo(ctx, aliceName);
  }).then(function(alice) {
    clientLib.prepareClient(ctx, alice);
    clientLib.setStatus('Ready');
  }).catch(function(err) {
    clientLib.setStatus('Error: ' + err);
  });
});
EOF
```

#### Bob HTML

Bob needs a corresponding HTML file:
```
cat - <<EOF >$V_TUT/browser/bob.html
<!DOCTYPE html>
<html>
<head>
  <title>Security - Bob</title>
</head>
<body>
  <br><h2>Bob</h2></br>
  <br>Default Blessings: <span id="default-blessings">----</span></br>
  <br><b>Peer Blessings:</b></br>
  <br><ul id="peer-blessings"></ul></br>
  <br>Status: <span id="status">Initializing...</span></br>
  <br></br>
  <br><input id="fortune-to-add" value="Fortune to Add"></input><button id="add-fortune">Add Fortune</button></br>
  <br><button id="get-fortune">Get Fortune</button></br>
  <br>Last Fortune: <span id="last-fortune">----</span></br>
  <script src="security-bob.js"></script>
</body>
</html>
EOF
```

### Carol
Carol operates nearly identically to Bob, except that she uses `alice:family:sister`
blessing that allows read / write access. In addition, Carol has functionality
to grant Diane a blessing with caveats.

#### Carol code

`src/security/carol.js` should contain:
```
cat - <<EOF >$V_TUT/src/security/carol.js
var vanadium = require('vanadium');
var showBlessingStore = require('./lib/show-blessing-store');
var clientLib = require('./lib/fortune-client');

var config = {
  logLevel: vanadium.vlog.levels.INFO
};

// Initialize Vanadium runtime
vanadium.init(config, function(err, runtime) {
  if (err) {
    throw new Error('Initialization error: ' + err);
  }
  runtime.on('crash', function(err) {
      throw new Error('The runtime has crashed unexpectedly and the page must be reloaded.');
  });

  showBlessingStore(runtime);
  initGranteeField(runtime);

  clientLib.setStatus('Waiting for Alice\'s blessings...');
  var aliceReqName = runtime.accountName.replace(/^dev.v.io:u:/, 'users/').replace(vanadium.security.ChainSeparator.val, '/') + // is this needed
    '/tutorial/alicerequest';
  var aliceName = runtime.accountName.replace(/^dev.v.io:u:/, 'users/').replace(vanadium.security.ChainSeparator.val, '/') + // is this needed
    '/tutorial/alice';
  var ctx = runtime.getContext();
  var client = runtime.getClient();
  var carolBlessings;
  client.bindTo(ctx, aliceReqName)
  .then(function(req) {
    var callOpts = client.callOption({
      allowedServersPolicy: [runtime.accountName + '/http%3A%2F%2F127.0.0.1%3A19101']
    });
    return req.getBlessings(ctx, callOpts);
  }).then(function(blessings) {
    carolBlessings = blessings;
    return runtime.principal.addToRoots(ctx, blessings);
  }).then(function() {
    return runtime.principal.blessingStore.set(ctx, carolBlessings, 'alice');
  }).then(function() {
    showBlessingStore(runtime);
    clientLib.setStatus('Connecting to Alice...');
    return client.bindTo(ctx, aliceName);
  }).then(function(alice) {
    clientLib.prepareClient(ctx, alice);
    onSendBlessings(runtime, carolBlessings, sendBlessingsToDiane);
    clientLib.setStatus('Ready');
  }).catch(function(err) {
    clientLib.setStatus('Error: ' + err);
  });
});


function sendBlessingsToDiane(runtime, carolBlessings, grantee, expiration, suffix) {
  var client = runtime.getClient();
  clientLib.setStatus('Connecting to Diane...');
  console.log('Connecting to grantee at: ' + grantee);
  client.bindTo(runtime.getContext(), grantee)
  .then(function(diane) {
    var expirationMs = expiration * 1000;
    var expirationTime = new Date(Date.now() + expirationMs);
    var granterCalled = false;
    var granterOption = client.callOption({
      granter: function(ctx, securityCall, cb) {
        console.log('In granter. Signing with key: ', securityCall.remoteBlessings.publicKey);
        granterCalled = true;
        runtime.principal.bless(ctx,
          securityCall.remoteBlessings.publicKey,
          carolBlessings,
          suffix,
          vanadium.security.createExpiryCaveat(expirationTime),
          function(err, blessing) {
            expectedBlessing = blessing;
            cb(err, blessing);
          });
      }
    });
    clientLib.setStatus('Granting a blessing to Diane...');
    return diane.grantBlessing(runtime.getContext(), granterOption);
  }).then(function() {
    clientLib.setStatus('Ready');
  }).catch(function(err) {
    clientLib.setStatus('Error sending blessings: ' + err);
  });
}

function onSendBlessings(runtime, carolBlessings, cb) {
  document.getElementById('send-grant').addEventListener('click', function() {
    var grantee = document.getElementById('grantee').value;
    var suffix = document.getElementById('grant-suffix').value;
    var expiration = parseInt(document.getElementById('grant-expiration').value);
    cb(runtime, carolBlessings, grantee, expiration, suffix);
  });
}
function initGranteeField(runtime) {
  var dianeName = runtime.accountName.replace(/^dev.v.io:u:/, 'users/').replace(vanadium.security.ChainSeparator.val, '/') + // is this needed
    '/tutorial/diane';
  document.getElementById('grantee').value = dianeName;
}
EOF
```

#### Carol HTML

Carol needs a corresponding HTML file:
```
cat - <<EOF >$V_TUT/browser/carol.html
<!DOCTYPE html>
<html>
<head>
  <title>Security - Carol</title>
</head>
<body>
  <br><h2>Carol</h2></br>
  <br>Default Blessings: <span id="default-blessings">----</span></br>
  <br><b>Peer Blessings:</b></br>
  <br><ul id="peer-blessings"></ul></br>
  <br>Status: <span id="status">Initializing...</span></br>
  <br><button id="send-grant">Send Grant</button> to <input id="grantee" value="---"></input> with suffix <input id="grant-suffix" value="guest:diane"></input> expiration time (seconds): <input id="grant-expiration" value="10"></input></br>
  <br></br>
  <br><input id="fortune-to-add" value="Fortune to Add"></input><button id="add-fortune">Add Fortune</button></br>
  <br><button id="get-fortune">Get Fortune</button></br>
  <br>Last Fortune: <span id="last-fortune">----</span></br>
  <script src="security-carol.js"></script>
</body>
</html>

EOF
```

### Diane
Diane gets the blessing `family:sister:guest:diane` from Carol with an expiry
caveat.

#### Diane code

Put the following in `src/security/diane.js`:
```
cat - <<EOF >$V_TUT/src/security/diane.js
var vanadium = require('vanadium');
var showBlessingStore = require('./lib/show-blessing-store');
var clientLib = require('./lib/fortune-client');

var config = {
  logLevel: vanadium.vlog.levels.INFO
};

var dianeService = {
  grantBlessing: function(ctx, serverCall) {
    console.log('In grantBlessing() localKey: ', serverCall.securityCall.localBlessings.publicKey);
    console.log('Grant blessing called');
    var grantedBlessings = serverCall.grantedBlessings;
    console.log('Granted blessings key: ', grantedBlessings.publicKey);
    var runtime = vanadium.runtimeForContext(ctx);
    var aliceName = runtime.accountName.replace(/^dev.v.io:u:/, 'users/').replace(vanadium.security.ChainSeparator.val, '/') + // is this needed
      '/tutorial/alice';
    console.log('alice name: ' + aliceName);

    clientLib.setStatus('Blessings received!');
    var client = runtime.getClient();
    runtime.principal.addToRoots(ctx, grantedBlessings)
    .then(function() {
      return runtime.principal.blessingStore.set(ctx, grantedBlessings, 'alice');
    }).then(function() {
      showBlessingStore(runtime);
      clientLib.setStatus('Connecting to Alice...');
      return client.bindTo(ctx, aliceName);
    }).then(function(alice) {
      clientLib.prepareClient(ctx, alice);
      clientLib.setStatus('Ready');
    }).catch(function(err) {
      clientLib.setStatus('Error: ' + err);
    });
  }
};

// Initialize Vanadium runtime
vanadium.init(config, function(err, runtime) {
  if (err) {
    throw new Error('Initialization error: ' + err);
  }
  runtime.on('crash', function(err) {
      throw new Error('The runtime has crashed unexpectedly and the page must be reloaded.');
  });

  showBlessingStore(runtime);

  clientLib.setStatus('Waiting for blessings...');

  // Create a server and serve the Diane's Service.
  var dianeName = runtime.accountName.replace(/^dev.v.io:u:/, 'users/').replace(vanadium.security.ChainSeparator.val, '/') + // is this needed
    '/tutorial/diane';
  console.log('dianeName: ' + dianeName);
  var dianeServiceConfig = {
    authorizer: function(ctx, secCall) {
      return undefined;
    }
  };
  runtime.newServer(dianeName, dianeService, dianeServiceConfig, function(err) {
    if (err) {
      throw new Error('Failed to serve ' + serviceName + ': ' + err);
    }
    console.log('Diane served');
  });
});
EOF
```

#### Diane HTML

Diane needs a corresponding HTML file:
```
cat - <<EOF >$V_TUT/browser/diane.html
<!DOCTYPE html>
<html>
<head>
  <title>Security - Diane</title>
</head>
<body>
  <br><h2>Diane</h2></br>
  <br>Default Blessings: <span id="default-blessings">----</span></br>
  <br><b>Peer Blessings:</b></br>
  <br><ul id="peer-blessings"></ul></br>
  <br>Status: <span id="status">Initializing...</span></br>
  <br></br>
  <br><input id="fortune-to-add" value="Fortune to Add"></input><button id="add-fortune">Add Fortune</button></br>
  <br><button id="get-fortune">Get Fortune</button></br>
  <br>Last Fortune: <span id="last-fortune">----</span></br>
  <script src="security-diane.js"></script>
</body>
</html>
EOF
```

## Running the code

### Combined HTML

`security.html` is an HTML page containing all of the above pages in iframes to
make it easier to observe changes.

There are four iframes, one each for Alice, Bob, Carol, and Diane. Alice will
always appear in the left frame. The iframes for Bob, Carol, and Diane can be
toggled using the "Show" buttons in the center of the page.

```
cat - <<EOF >$V_TUT/security.html
<!DOCTYPE html>
<html>
<head>
  <title>JavaScript Security Tutorial</title>
  <style>
    .hidden {
      display: none;
    }
  </style>
</head>
<body style="background: #000000;">
  <div style="position:fixed;top:0vh;left:0vh;bottom:0vh;width:47vw; background: #ffffff;">
    <iframe id="Alice" src="http://127.0.0.1:19101/browser/alice.html" style="width:100%; height:100%;" frameBorder="0"></iframe>
  </div>
  <button style="position:fixed;top:0vh;left:47vw;bottom:0vh;width:6vw;height:5vh;" id='Bob-button'>Show Bob</button>
  <button style="position:fixed;top:5vh;left:47vw;bottom:0vh;width:6vw;height:5vh;" id='Carol-button'>Show Carol</button>
  <button style="position:fixed;top:10vh;left:47vw;bottom:0vh;width:6vw;height:5vh;" id='Diane-button'>Show Diane</button>
  <div id="Bob-div" style="position:fixed;top:0vh;right:0vw;bottom:0vh;width:47vw; background: #ffffff;">
    <iframe id="Bob" src="http://127.0.0.1:19102/browser/bob.html" style="width:100%; height:100%;" frameBorder="0"></iframe>
  </div>
  <div id="Carol-div" style="position:fixed;top:0vh;right:0vw;bottom:0vh;width:47vw; background: #ffffff;" class="hidden">
    <iframe id="Carol" src="http://127.0.0.1:19103/browser/carol.html" style="width:100%; height:100%;" frameBorder="0"></iframe>
  </div>
  <div id="Diane-div" style="position:fixed;top:0vh;right:0vw;bottom:0vh;width:47vw; background: #ffffff;" class="hidden">
    <iframe id="Diane" src="http://127.0.0.1:19104/browser/diane.html" style="width:100%; height:100%;" frameBorder="0"></iframe>
  </div>
  <script type="text/javascript">
    var people = [
      'Bob',
      'Carol',
      'Diane'
    ];
    function showDiv(name) {
      people.forEach(function(p) {
        document.getElementById(p + '-div').classList.toggle('hidden', name !== p);
      });
    }

    people.forEach(function(p) {
      document.getElementById(p + '-button').addEventListener('click', showDiv.bind(null, p));
    });
  </script>
</body>
</html>
EOF
```

### Helper script

To help run it, the following `run-security.sh` script will be used:
```
cat - <<EOF >$V_TUT/run-security.sh
echo "Browserifying..."

NODE_PATH=$V_TUT
$V_TUT/node_modules/.bin/browserify --debug $V_TUT/src/security/alice.js -o $V_TUT/browser/security-alice.js
$V_TUT/node_modules/.bin/browserify --debug $V_TUT/src/security/bob.js -o $V_TUT/browser/security-bob.js
$V_TUT/node_modules/.bin/browserify --debug $V_TUT/src/security/carol.js -o $V_TUT/browser/security-carol.js
$V_TUT/node_modules/.bin/browserify --debug $V_TUT/src/security/diane.js -o $V_TUT/browser/security-diane.js

echo "Serving..."
$V_TUT/node_modules/.bin/static $V_TUT -p 19101 > /dev/null &
PID_SERV1=$!
$V_TUT/node_modules/.bin/static $V_TUT -p 19102 > /dev/null &
PID_SERV2=$!
$V_TUT/node_modules/.bin/static $V_TUT -p 19103 > /dev/null &
PID_SERV3=$!
$V_TUT/node_modules/.bin/static $V_TUT -p 19104 > /dev/null &
PID_SERV4=$!
$V_TUT/node_modules/.bin/static $V_TUT -p 8989 > /dev/null &
PID_SERV5=$!

function killservers() {
  kill $PID_SERV1
  kill $PID_SERV2
  kill $PID_SERV3
  kill $PID_SERV4
  kill $PID_SERV5
}
trap killservers EXIT

sleep infinity
EOF
```

Make the script runnable. Then, run the script.

```
bash $V_TUT/run-security.sh
```

The console will show "Browserifying..." and then "Serving...".

### Loading the page
{{# helpers.warning }}

**On the first run, you will be asked to allow each domain to be blessed.**

Recall that we are running this example across 4 origins. Since the extension
will bless each iframe based on origin, up to 4 blessing tabs will appear.

Click "Bless" on each of the tabs.

**On each load, you will also be prompted to Bless Bob and Carol.**

The page will prompt you with a dialog entitled "The page at 127.0.0.1:19101 says".

This occurs because Bob and Carol are asking for blessings. The prompt prefills
the input section with "friends:bob" (for :19102) and "family:sister" (for :19103).

In practice, Alice would use this opportunity to verify that she is indeed
allowing Bob and Carol to receive a blessing from her.

The tutorial expects Alice to send the blessing strings that are pre-filled in
the prompt box, but feel free to experiment with different ones.
{{/ helpers.warning }}

Now, go to http://127.0.0.1:8989/security.html .
You should see four iframes, one each for Alice, Bob, Carol, and Diane.

### Using the example
After Bob and Carol are blessed, the blessings they received from Alice should
be visible in their respective windows.

Try requesting a fortune as Bob and Carol. Each should be given access, and a
fortune should be retrieved.

Now, try adding a fortune as Bob and Carol. Bob should get an error
indicating failure because he is only a friend. In contrast, Carol's request
should succeed because she is family. The fortune should appear on Alice's display.

Now let's give Diane a blessing. Go to Carol's iframe and Press the "Grant"
button. This sends a blessing to Diane (alice:family:sister:guest:diane).

Until the designated expiration time (default 10s),
Diane should be able to both add and get a fortune, as if she were family.

Once the blessing expires, Diane is no longer able to access Alice's fortunes
until Carol grants her another blessing.

## Summary

We need a summary.

[Fortune tutorial]: /tutorials/javascript/fortune.html
[Permissions Authorizer tutorial]: /tutorials/security/permissions-authorizer.html
[Security Tutorials]: /tutorials/security
