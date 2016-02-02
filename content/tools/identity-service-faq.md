= yaml =
title: Vanadium Identity Service
toc: true
= yaml =

The Vanadium Identity Service is a cloud service that is a [blessing root] for
blessing names that begin with `dev.v.io`. Applications can choose to
[recognize][blessing root] the authority of this service in order to broker
authentication between different [principals] that the application communicates
with.

The web interface for this service is accessible at https://dev.v.io/auth and
the design of this service (along with how to obtain a blessing from it) is
described in [this document][design-doc].

Some frequently asked questions about this service follow.

# What information is stored by the service?

In order to obtain a blessing from this service, one must sign-in using their
Google Account. For each blessing created by this service, the following is
recorded:

- Email address associated with the Google account that was used to
  authenticate with the service
- The timestamp at which the blessing was created
- The certificate chain for the blessing

Additionally, for each revocable blessing granted, the service also stores the
timestamp at which the revocation happened (or the fact that the blessing has
not yet been revoked).

All user-information stored by this service is accessible to the owner of the
Google Account at https://dev.v.io/auth/google/listblessings

# Why is the default caveat a revocation caveat?

When creating a blessing of the form `dev.v.io/users/<email_address>` (after
using Google OAuth to determine the email address), the user is asked to select
a set of caveats to be placed on the blessing.

By default, this form is pre-populated with a _revocation caveat_, which means
that the blessing is valid until explicitly revoked by the user. The user may
chose to remove this default caveat and insert other caveats instead.

Revocation (as opposed to say setting a short-lived expiration caveat) was chosen
as the default for two reasons:

1. Gives the user finer control over blessings issued to them.
   The user can choose to revoke these blessings at any time, rendering them
   ineffective.
2. Allows the blessings to be long-lived. Blessings that aren't revoked are
   always valid, so the user doesn't have to concern themselves with "managing"
   the validity of blessings by keeping track of when they expire and when they
   have to be re-issued.

This choice of default may be revisited based on user feedback.

# What information is provided to this service on discharge requests?

Use of the revocation caveat implies that the granted blessing is valid only
when accompanied with a [discharge] issued by the identity service. This means
that use of the blessing requires a periodic RPC to the identity service in
order to obtain the discharge. This request to obtain a discharge only
sends information about the caveat, no information on why the discharge is
being requested is sent to this service.

# What are the terms of service for using the Vanadium Identity Service?

Use of this service (including obtaining a blessing from it or listing
blessings obtained from it) is subject to the [terms of service] of all cloud
services hosted at v.io.

# Where can I find the code that backs this service?

https://github.com/vanadium/go.ref/services/identity/identityd/main.go

[blessing root]: ../glossary.html#blessing-root
[Vanadium Security Model]: ../concepts/security.html
[principals]: ../glossary.html#principal
[design-doc]: ../designdocs/identity-service.html
[terms of service]: ../tos.html
[discharge]: ../glossary.html#discharge
