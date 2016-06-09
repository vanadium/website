= yaml =
title:
fullTitle: Vanadium Core
= yaml =

Vanadium Core is the discovery, RPC, and security layer underlying Syncbase.
It enables building secure, distributed applications that can run anywhere.
It provides:
<div class="intro-detail intro-detail-security">
   <p>
      **Complete security model**<br>
      Vanadium's security model is based on public-key cryptography, that supports
      fine-grained permissions and delegation. The combination of traditional ACLs
      and "blessings with caveats" supports a broad set of practical requirements.
      <p>[Learn more about Security](/concepts/security.html)</p>
   </p>
</div>
<div class="intro-detail intro-detail-codebase">
   <p>
      **Symmetrically authenticated and encrypted RPC**<br>
      Vanadium Core provides symmetrically authenticated and encrypted RPC, with
      support for bi-directional
      messaging, streaming and proxying, that works on a variety of network
      protocols, including TCP and Bluetooth. The result is a secure communications
      infrastructure that can be used for large-scale datacenter applications as
      well as for smaller-scale enterprise and consumer applications, including
      those needing to cross NAT boundaries.
      All data on the wire is encoded using Vanadium Object Marshalling (VOM),
      which is a performant, self-describing encoding format.
      <p>[Learn more about RPC System](/concepts/rpc.html)</p>
   </p>
</div>
<div class="intro-detail intro-detail-discovery">
   <p>
      **Distributed naming and discovery**<br>
      Vanadium provides a global naming service that offers the convenience of
      urls but allows for federation and multi-level resolution. The
      'programming model' consists of nothing more than invoking methods on
      names, subject to security checks. Vanadium also provides a discovery API
      for advertising and scanning for services over a variety of protocols,
      including BLE and mDNS (Bonjour).
      <p>[Learn more about Naming](/concepts/naming.html)</p>
   </p>
</div>

# Ready to get started?

<p>Vanadium is an open source effort, and we welcome your contributions.
Get started now by exploring the tutorials.</p>
<a href="/tutorials/hello-world.html" class="button-passive">
Start the tutorial</a>