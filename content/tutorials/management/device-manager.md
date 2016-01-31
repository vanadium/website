= yaml =
title: The Device Manager
layout: tutorial
wherein: you learn about running applications with the device manager
prerequisites: {scenario: b}
sort: 51
toc: true
= yaml =

# Introduction

In the [basics tutorial], you ran the fortune server as a background process
from the terminal.

In this tutorial, you'll learn how to use the device manager to run your server
remotely (however, the device manager you'll be running as part of the tutorial
is running on the same computer to keep things simple).

# Credentials

We'll be using default [credentials] for all the commands and servers we start
from the terminal. Recall that `tutorial` is the blessing name for these credentials:

<!-- @setCredentials @test -->
```
export V23_CREDENTIALS="$V_TUT/cred/basics"
"${V_BIN}/principal" dump -s
```

# Install and start a device manager

The __device manager__ is a Vanadium application that runs on a device and is
responsible for installing and running other Vanadium applications on behalf of
users.

The first step is to install and start a device manager on your computer (taking
care first to clean up any previous ones). The device manager uses the security
agent introduced in the [agent tutorial] to manage principals for itself and all
the applications run under it.

The device manager has a built-in mount table, which we can us for service
discovery (as we learned in the [mount table tutorial]). So give it a fixed
port.

<!-- @installAndStartDeviceManager @test @sleep -->
```
export V23_DEVICE_DIR="$V_TUT/devmgr"
PORT_MT=24000
"${V_BIN}/deviced" stop 2>/dev/null
"${V_BIN}/deviced" uninstall --suid_helper="${V_BIN}/suidhelper"
V23_CREDENTIALS="" "${V_BIN}/deviced" install --suid_helper="${V_BIN}/suidhelper" --agent="${V_BIN}/agentd" -- --v23.tcp.address=":$PORT_MT" --name=""
V23_CREDENTIALS="" "${V_BIN}/deviced" start
```

Check that the device manager service is mounted in the mount table. This
should print `/:24000/devmgr`:
<!-- @globMountTable @test -->
```
"${V_BIN}/namespace" glob "/:$PORT_MT/*"
```

# Claim the device manager

The device manager is currently __unclaimed__, meaning that it does not have a
blessing (other than the one it generates for itself).  The user must __claim__
the device manager to unlock its functionality.  Claiming involves conferring a
blessing, which then becomes the device manager's default blessing. We'll bless
our device manager as `hal`, and verify that the device manager presents itself
as `tutorial/hal`:

<!-- @claimDeviceManager @test -->
```
DEVICE_NAME=/:$PORT_MT/devmgr
"${V_BIN}/device" claim "${DEVICE_NAME}/device" hal
"${V_BIN}/vrpc" identify "${DEVICE_NAME}/device"
```

# Bring up a server

We're now ready to deploy a Vanadium application on the device manager. We'll
use the fortune server as our application.

First, install the application, recording the installation name:

<!-- @installFortune @test -->
```
INSTALLATION_NAME=$( \
  "${V_BIN}/device" install-local "${DEVICE_NAME}/apps" \
  fortuneserver "${V_TUT}/bin/server" --service-name=myFortunes \
)
echo "Installed: ${INSTALLATION_NAME}"
```

Then create an instance of the application just installed and run it, providing
the instance with a blessing called `fortune`. Record the instance name:

<!-- @startFortune @test -->
```
INSTANCE_NAME=$("${V_BIN}/device" instantiate "${INSTALLATION_NAME}" fortune)
"${V_BIN}/device" run "${INSTANCE_NAME}"
echo "Instantiated and started: ${INSTANCE_NAME}"
```

Verify that the fortune server app runs with the expected blessing name, `tutorial/fortune`:
<!-- @identifyFortune @test -->
```
"${V_BIN}/vrpc" identify "/:$PORT_MT/myFortunes"
```

At this point, you can look at the log files from your server. To see what log files are available:
<!-- @listLogFiles @test -->
```
 ${V_BIN}/namespace glob "${INSTANCE_NAME}/logs/*"
```

You can use _debug logs read_ to read any of these files. For example:
<!-- @readLogFiles @test -->
```
LOGFILE=`${V_BIN}/namespace glob "${INSTANCE_NAME}/logs/STDOUT-*"`
${V_BIN}/debug logs read $LOGFILE
```

# Run the client

As in the [basics tutorial], use the client to make a call to the server:

<!-- @fortuneClient @test -->
```
"${V_TUT}/bin/client" --server "/:$PORT_MT/myFortunes"
```

# Cleanup
<!-- @deviceManagerCleanup @test -->
```
"${V_BIN}/device" kill "${INSTANCE_NAME}"
"${V_BIN}/deviced" stop
"${V_BIN}/deviced" uninstall --suid_helper="${V_BIN}/suidhelper"
```

# Summary

You set up a device manager on your computer, and used the `device` command-line
tool to install and start an application on it.

[basics tutorial]: /tutorials/basics.html
[agent tutorial]: /tutorials/security/agent.html
[mount table tutorial]: /tutorials/naming/mount-table.html
[credentials]: /tutorials/basics.html#authorization
