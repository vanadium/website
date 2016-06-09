= yaml =
title: Example Apps
toc: true
= yaml =

# Physical Lock

* Repo: https://github.com/vanadium/physical-lock

[Physical Lock][lock] defines the software for building a secure physical lock
using the Vanadium stack, along with a commmand-line tool for interacting with
the lock.
The software runs on a Raspberry Pi and interacts with the locks's switches and
sensors using GPIO. It runs a Vanadium RPC service that allows clients to send
lock and unlock requests.

Key distinguishing aspects:
* *Decentralized:* There is no single authority on all the locks, no cloud server
that controls access to all locks from a particular manufacturer. All secrets and
credentials pertaining to a particular lock are solely held by the lock and its
clients. Huge compute farms run by hackers all over the world have no single
point of attack that can compromise the security of multiple locks.
* *No Internet Connectivity Required:* The lock does not require internet
connectivity to function. When you’re right in front of the device, you can
communicate with it directly without going through the cloud or a third-party
service.
* *Audited:* The lock can keep track of who opened the door, when and how they
got access.

For more information, see the [README][lock-readme].

[lock]: https://github.com/vanadium/physical-lock
[lock-readme]: https://github.com/vanadium/physical-lock/blob/master/README.md
