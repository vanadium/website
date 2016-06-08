= yaml =
title: My Cloud Syncbase
layout: syncbase
toc: true
= yaml =

# Introduction

The Syncbase Allocator service at
[https://sb-allocator.v.io/](https://sb-allocator.v.io/) (log in with Google
required) allows you to create and manage up to 3 free cloud Syncbase instances.

Each instance is running in a dedicated container, isolated from all the other
instances.  Access is restricted to the creator of the instance.

{{# helpers.warning }}
## Please note

The instances are meant to be used for development.  There are no guarantees
about availability or performance.  Data stored in the instances can be lost at
any time.  No sensitive or personal data should be stored in the instances.
{{/ helpers.warning }}

# Usage

## Viewing your Instances

After logging in, you'll see a list of all your instances (sorted in reverse
chronological order by creation time).  Each instance displays its address and
blessing patterns.  You can manage your instances from this view.

## Creating an Instance

The `CREATE NEW` button spins up a new syncbase instance.  It takes about 25
seconds, after which you'll see your newly created instance.  The instance is
assigned a stable address that makes reachable from clients and peers.

## Destroying an Instance

The `DESTROY` button removes the instance.  Note, all data in the instance is
lost; this operation cannot be undone.

## Suspending/Resuming an Instance

The `SUSPEND` button allows you to stop your instance.  `RESUME` restarts it.
The data in the instance is preserved.

## Resetting an Instance

The `RESET` button re-creates the instance's persisted storage.  Note, all data
in the instance is lost; this operation cannot be undone.  Resetting preserves
the instance's address and blessing patterns, which makes it a suitable
alternative to destroying and recreating an instance when stability of the
address and blessing patterns is desired.

## Inspecting an Instance

The `DASHBOARD` button opens a page showing load and resource utilization for
the instance.  The `DEBUG` button opens a page showing details about the
instance like its blessings, stats, and a browse view of the databases.
