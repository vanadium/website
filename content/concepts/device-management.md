= yaml =
title: Device Management
sort: 4
toc: true
= yaml =

Vanadium targets a broad range of compute devices and environments. Vanadium's device management system securely integrates physical devices and software applications available in the system.

# Devices and applications

A __device__ abstracts a system running Vanadium software, although the device need not be exclusively for Vanadium apps - for example, the system could be running natively installed applications alongside Vanadium applications. Typically, a device is a physical computing device, but a device could also be a virtual machine or a browser environment.

An __application__ is a piece of software built using Vanadium. We use "app" as shorthand for "application", without adopting any of the specific meanings the term "app" may have elsewhere (e.g. in the context of mobile device app stores). Vanadium applications instantiate the Vanadium runtime. Usually, a running instance of a binary corresponds to an application, though applications can be multi-processed, or can be scripts (such as Node.js applications), or can be [Docker][docker] images.

Applications are described by an __application envelope__. The envelope
contains information needed by the device to install and run the application,
like the application title, location of its binary or script, and configuration settings.

Devices, as environments for apps, are characterized by their ability to build, install, and run apps. Except in tightly controlled organizations, the landscape of devices is typically diverse. Vanadium introduces the concept of a __profile__ in order to prevent application publishers and device administrators from having to contend with myriad possible device setups.

A profile abstracts the characteristics of a physical device, its operating system, and available libraries. It is essentially a label for a particular configurations of devices, though the level of specificity will depend on the profile author. For example, a label could be as generic as `android` or as specific as `raspberry-ubuntu-14.04-media`. A device with a given profile is expected to be able to install and run applications built for that profile, and heterogeneous devices should be able to usefully support the same profile. Profiles may also be used to match configuration requirements and parameters, security policies or any piece of management information that may need to vary based on the type and configuration of a given device.

A device can be assigned a profile manually, or it can programmatically deduce the set of profiles with which it is compatible. If no known profile matches the device, the device is automatically given a profile that is unique to it.

Devices are matched with apps by an __application repository service__. The matching is based on profiles: the device presents the service with the profiles it supports, and the service returns the envelope for the application that matches at least one of the profiles presented.

Matching apps with devices based on profiles is also how our build system ensures that it provides test coverage without having to support all possible machine configurations. Devices that test a given app can report back with a test status for the profile they support.

Application binaries, scripts, docker images, or related data resources (e.g. images, style sheets) are stored in a __binary repository service__. The binary service allows uploading and downloading arbitrary binary blobs identified by their object name.

# Device manager service

Vanadium provides remote management APIs to manage devices and apps.

Each device runs the Vanadium __device manager service__. The device manager
allows RPCs to control the device's state and security properties (such as
ownership and access privileges). The device manager also manages applications
running on the device.

An __application installation__ is an object corresponding to an application
envelope that was downloaded and installed by the device. A device can have several
installations of the same application at any point in time (perhaps at different
versions of the application). Each running instance of an application
installation is represented by an __application instance__ object. There can be
zero or more instances for every application installation. Each application
instance is provided with its own private local storage.

Each application installation and each application instance is identified by an
object name implementing the __application service__. This allows operations
such as installation/uninstallation of applications,
starting/stopping/restarting of instances, updating application versions, and
suspension/resumption of execution:

  * `Install`/`Uninstall`: install a new application or uninstall the
    application installation.
  * `Instantiate`/`Delete`: create or destroy an instance of an application. Resources such as per-instance storage are allocated upon instantiation and reclaimed upon deletion.
  * `Run`/`Kill`:  start or stop the execution of an application instance. Per-instance
  storage persists between runs of the instance.

The __object naming scheme__ is as follows:
  * `<device name>/device`: device manager service for device
  * `<device name>/apps/<app title>/<installation id>`: application service for
    installed application
  * `<device name>/apps/<app title>/<installation id>/<instance id>`: application
    service for an instance of the installed application

For example,
  * `<device name>/apps/google maps/0.Uninstall()`: uninstalls installation 0
    of the Google Maps app
  * `<device name>/apps/google maps/0/5.Kill()`: stops running instance 5 of
    installation 0 of the Google Maps app

Globbing at any level of the name hierarchy reveals the appropriate subtree of
application installations and instances.

Each application exposes the __app cycle manager service__ in addition to any
other methods that the application may chose to expose. The app cycle manager
service allows the device manager process to communicate with each app it runs
for operations such as cleanly shutting down the app.

# Security and identities

The __security model__ revolves around which principals are allowed to perform
which management operations, and around what capabilities an app is given on a
device (see [Security Concepts][vanadium-security] for an overview of
security primitives).

## Device and application identities

Each device is owned by the identity of the principal who claims it. All
permissions are initially restricted to the owner, who may update the
permissions on the administrative and operational methods as needed.
Management methods for an application installation or instance are initially
restricted to the same principal that installed or started it, and to the
administrator(s) of the device.

When a client asks the device manager to start an application instance, the
client principal must provide the application instance with a blessing which
becomes the default blessing for the principal of the application instance.

## Application permissions

Applications come signed by a publisher's identity which is verified by the
device before installing the application.

In the future, it will be possible to give applications permission on the
device according to the device owner's trust relation with the publisher. For
example, the owner may trust applications published by "Google Inc." with all
capabilities, whereas she may trust applications published by "XYZ Games
Corp." with access only to the screen and speakers. An application can request
further capabilities as needed when it's running. On receiving requests, the
user may allow or disallow based on their personal comfort level and/or on the
perceived value of the app feature requesting the new capability.

[docker]: https://www.docker.com/
[vanadium-security]: /concepts/security.html
