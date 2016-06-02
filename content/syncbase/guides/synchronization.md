= yaml =
title: Syncing Data
layout: syncbase
sort: 3
toc: true
= yaml =

# Introduction

Syncbase's sync protocol is peer-to-peer whereas most other sync systems require
a centralized server. We believe that despite internet connectivity becoming
more and more prevalent, there will always be times when an internet connection
is not available. You should be able to sync with your peer, with very low
latency, when you are physically close. For example, you shouldn't need an
internet connection to set the temperature on your thermostat. Syncbase uses the
cloud as another, very durable peer, but the cloud is not required for any two
peers to interact. Because the cloud is not in the critical path for synchronization,
apps can use Syncbase as for asynchronous, relatively low latency communication.

Peer-to-peer sync, however, introduces problems not present in client-server sync:
* Sub-groups of devices can collaborate independently, leading to substantial
data conflicts.
* Malicious peers can perform man-in-the-middle attacks. The system should
prevent them.

Syncbase internally handles both of these issues by providing:
 * Automatic conflict resolution policies such as last-one-wins and an upcoming
 extensive conflict resolution API for custom conflict resolution.
 * Strong security and access control. To prevent read-only peers
 from performing a man-in-the-middle attack, Syncbase will sign the mutations
 on behalf of the writer. The receivers automatically verify the signatures.

# Using Syncgroups
A syncgroup is a set of of collections that are synchronized amongst a set of
users (and with the cloud, if available).

By default, creating a collection creates an associated syncgroup, initially
synced amongst the creator’s devices but other users can also be added to this
syncgroup to allow sharing.

## Sharing collections

Sharing collections involves **inviting** other users to **join** a collection's
syncgroup. Upon inviting a user, the invitee **receives an invite event**. When
an invite is **accepted**, the inviter's syncgroup will be joined and shared data
will start syncing.
When inviting a user, an access level can be specified:
* *read-only*: Invitee can only read the shared data rows.
* *read-write*: Invitee can read, put and delete data rows and mutations will
sync with anyone else who is part of the syncgroup.
* *read-write-admin*: In addition to read-write, can invite others to join the
syncgroup, eject existing members of the syncgroup or change their access level.

On the inviter side, we just need to invite a user to join the collection's
syncgroup:
```
Collection collectionToShare = db.collection("myCollection");

User userToInvite = new User("<email-address>");

collectionToShare.getSyncgroup().inviteUser(userToInvite, AccessLevel.READ);
```

On the invitee side, we need to handle invite requests by registering a handler:
```
db.addSyncgroupInviteHandler(new Database.SyncgroupInviteHandler() {
    @Override
    public void onInvite(SyncgroupInvite invite) {
        // Prompt the user if desired then accept or reject the invite.
        db.acceptSyncgroupInvite(invite);
    }
});
```

{{# helpers.info }}
### Tip
`db.removeAllSyncgroupInviteHandlers()` can be used in activity's `onDestroy`
to remove all registered invite handlers.
{{/ helpers.info }}

When an invitation is accepted, Syncbase automatically joins the inviter's
syncgroup and the associated collection and its data will start
syncing into the invitee's database. As the collection syncs, data will be
surfaced through the *Watch API*. See [Data Flow] guide for details on how
to model your app's data flow.

## Unsharing collections

Ejecting a user from a collection's syncgroup will unshare the collection. If
the target user has not accepted the invitation yet, the invite will simply
disappear. Otherwise, the shared collection on target user's database will
become read-only and will no longer sync and receive updates.

```
Collection sharedCollection = db.collection("myCollection");

User userToRemove = new User("<email-address>");

sharedCollection.getSyncgroup().ejectUser(userToRemove);
```

## Updating Access Level

Simply re-inviting an already invited user with a different access level will
update their access without triggering a new invitation.

## Listing All Syncgroups

`db.getSyncgroups()` can be used to list all syncgroups. This list includes
pre-created syncgroups for collections and other syncgroups created or joined.

```Java
Iterator<Syncgroup> allSyncgroups = db.getSyncgroups();
while(allSyncgroups.hasNext()) {
    Syncgroup sg = allSyncgroups.next();
}
```

# Summary

* Syncbase's sync protocol is peer-to-peer.
* By default, creating a collection creates an associated syncgroup, initially
synced amongst the creator’s devices.
* Sharing collections is done by inviting other users to join a collection's
syncgroup.
* Access-level can be one of read-only, read-write, or read-write-admin.

[Data Flow]: /syncbase/guides/data-flow.html