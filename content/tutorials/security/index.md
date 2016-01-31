= yaml =
title: Overview
layout: tutorial
sort: 20
toc: false
= yaml =

In Vanadium, all communication channels are encrypted and
authenticated, and all communication must satisfy an authorization
policy.

The following tutorials build from the [Client/Server Basics tutorial][client-server] to demonstrate code and pre-built tools that implement and benefit from
Vanadium security.

*  [Principals and Blessings]<br>
  _Wherein_ Alice and her friend Bob take the stage to
  demonstrate inter-principal communication.

* [Permissions]<br>
  _Wherein_ you meet a built-in authorizer that that lets Alice grant
  fine-grained access to Bob and Carol with simple lists of names.

* [Caveats]<br>
  _Wherein_ Carol delegates the access that Alice gave her to Diane.
  Carol does so without bothering Alice and without leaking secrets.
  Carol constrains Diane's power with _caveats_.

* [Third-Party Caveats]<br>
  _Wherein_ you arrange for your lawyer to get access to your
  "documents", then revoke that access.

* [The Agent]<br>
  _Wherein_ you use a _security agent_ to maintain your secrets and
  facilitate your secure use of Vanadium.

* [Custom Authorizer]<br>
  _Wherein_ you craft a custom authorizer for Alice that grants family
  access any time of day, but constrains friends to a time window.

That introduces the generalities.  Aspects of security that are
focused on particular subjects will be covered in related subject
tutorials, e.g. the [JavaScript tutorial] and the [Mount table tutorial].

The [Security Concepts document] provides a general discussion of
Vanadium security that complements these security tutorials.

[Permissions]: /tutorials/security/permissions-authorizer.html
[Custom Authorizer]: /tutorials/security/custom-authorizer.html
[Principals and Blessings]: /tutorials/security/principals-and-blessings.html
[The Agent]: /tutorials/security/agent.html
[Caveats]: /tutorials/security/first-party-caveats.html
[Third-party Caveats]: /tutorials/security/third-party-caveats.html
[client-server]: /tutorials/basics.html
[JavaScript tutorial]: /tutorials/javascript/hellopeer.html
[Security Concepts document]: /concepts/security.html
[Mount table tutorial]: /tutorials/naming/mount-table.html
