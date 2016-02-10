= yaml =
title: Vanadium Chrome Extension
toc: true
= yaml =

The [Vanadium Chrome extension] is a bridge between JavaScript web apps and
the Vanadium runtime, libraries, and services.

Support for web applications is a work-in-progress.  Currently, Vanadium web
apps can run only in the Chrome desktop browser with the [Vanadium Chrome
extension] installed.  Mobile browsers and non-Chrome browsers will be
supported in the future.

# Overview

The Vanadium codebase is written mostly in [Go].  In order to make the Go
libraries accessible to a JavaScript web app, the Vanadium Go code is compiled
into a [Native Client] (NaCl) plugin and embedded in a Chrome extension.

[Native Client] is a sandbox for running compiled binary code in
the browser efficiently and securely, independent of the user's operating
system type.  These plugins can make use of the [Pepper API].

Traditionally, NaCl has supported only C and C++ compilation, but the Vanadium
team has extended the Go compiler to target NaCl and the Pepper API.

The [Vanadium JavaScript library] provides a set of JavaScript APIs for
interacting with the Vanadium Go code running inside the NaCl plugin in the
extension.

Under the hood, the Vanadium JavaScript library sends messages to the Vanadium
extension, which makes calls to other Vanadium devices in the cloud.  The
extension sends messages back to the web app when those calls return, or when
an external device initiates a call to the JavaScript client.

![Vanadium Chrome extension overview](/images/chrome-extension-overview.svg)

Isolating the Vanadium libraries inside a NaCl plugin has the added benefit
that no JavaScript web app ever sees any private keys.  All cryptographic
operations are performed within the extension's NaCl sandbox.

# Vanadium Chrome extension details

The Vanadium extension has two main components:
  * a [content script] that runs on each tab, and
  * a [background page] that runs once per browser and contains JavaScript code and a NaCl plugin.

The following diagram depicts these components and the flow of messages between them.

![Vanadium Chrome extension details](/images/chrome-extension-detail.svg)

When a web app makes an RPC to a device using the Vanadium JavaScript library,
a message is sent to the content script, which then forwards that message to
the JavaScript running in the background page, and from there the message is
sent to the NaCl plugin.  The NaCl plugin handles incoming messages from
JavaScript by calling Vanadium library code, written in Go.

The NaCl plugin makes Vanadium RPCs to other Vanadium devices using WebSockets,
which are a supported transport protocol of the Vanadium RPC protocol.  Within
the NaCl plugin, each web app origin is associated with a unique [Vanadium
blessing][blessing], and RPCs are performed with the blessing associated with
the origin of the web app making the request.

The plugin sends messages back to web apps using the same message-passing
system, but in reverse: a message is first sent from NaCl to the background
page JavaScript, then to the content script running on the same tab as the web
app, and finally to the web app.

[background page]: https://developer.chrome.com/extensions/background_pages "Background Pages"
[blessing]: /glossary.html#blessing
[content script]: https://developer.chrome.com/extensions/content_scripts "Content Scripts"
[Go]: http://golang.org/ "The Go Programming Language"
[Native Client]: https://developer.chrome.com/native-client "Native Client"
[Pepper API]: https://developer.chrome.com/native-client/c-api "Pepper API"
[Vanadium Chrome extension]: https://chrome.google.com/webstore/detail/jcaelnibllfoobpedofhlaobfcoknpap "Vanadium Chrome extension"
[Vanadium JavaScript library]: https://github.com/vanadium/js "Vanadium JavaScript"
