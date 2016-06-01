= yaml =
title: Coffee Catalog
layout: syncbase
toc: false
= yaml =

# Functionality

Allows a user to order coffee and related paraphernalia.

## Key Behaviors

* Browse catalog
    * Each item in catalog has image, description, price, etc.
    * Catalog has ~100 entries, so it fits entirely on any device
    * Show "frequently ordered" items at the top
* Place orders for items in the catalog
    * User’s address, credit card, etc. saved by app (and synced
      across user’s devices) for future use
* Review order history
* All of above should work while offline
    * Notification if order is not processed within 1 day

# Schema

## Data Types
```Go
type Item struct {
  Id    string // UUID
  Image BlobRef
  Desc  string
  Price float
}

type User struct {
  Id         string // UUID
  // In reality we might define structs for some of the values below.
  Name       string // full name of user
  Email      string
  Address    string
  CreditCard string // should instead use a more secure API (token per order?)
}

type OrderItem struct {
  ItemId string
  Count  int
}

type Order struct {
  Id           string // UUID
  CreatedTime  time.Time
  PlacedTime   time.Time // zero value if not yet placed
  ReceivedTime time.Time // zero value if not yet received
  // We’d probably have more fields here, e.g. to specify
  // gift-wrapping options, track order status, etc.
}
```
## Organization
```
<app-blessing>-catalog Collection
  <Item.Id>: Item

<user-blessing>-user Collection
  <User.Id>: User
  // possibly also include per-user catalog metadata, e.g. favorites

<user-blessing>-draftOrders Collection
  <Order.Id>: Order
  <Order.Id>/items/
    <Item.Id>: OrderItem

<user-blessing>-placedOrders Collection - same layout as draftOrders
<user-blessing>-processedOrders Collection - same layout as draftOrders
```

{{# helpers.info }}
### Note
We might keep user records in a "users" table and order records in an
“orders” table in order to enforce schema, but this is orthogonal to
collection layout.
{{/ helpers.info }}

When a user "places" an order, all data for the order is moved (copy + delete)
atomically from the “draftOrders” to the “placedOrders” collection.

The app cloud backend (order processor) watches for changes to "placedOrders"
and processes these orders. After processing an order, it sets
Order.ReceivedTime and atomically moves the order record from the
“placedOrders” to the “processedOrders” collection. Whenever watch stops for
any reason, it is restarted including the initial state to prevent skipping
any orders. Order processing must also be either atomic with the move to
“processedOrders”, or idempotent to allow safely retrying without executing
more than once in case commit fails. It might need to snapshot orders in
processing to its own local storage as an extra safeguard (e.g. in case a
malicious user changes an order after it’s accepted for processing).

The client app periodically queries "placedOrders" and notifies users of any
orders that have not yet been received.

To aid in frontend development, the app would likely implement some ORM-like
wrappers and helper functions, e.g. an "order" object that directly contains a
list of items (to simplify view rendering) and functions to add, remove, or
update items in a draft order (to simplify writing back to the store).

# Syncing and permissions

Let "bluebottle" be the blessing for the administrator/owner of the store.

* All users are readers (preferably anonymized) in a syncgroup on "catalog",
  with “bluebottle” as RWA. “bluebottle” is also a syncgroup admin (sgA),
  other users may be as well for more flexible distribution to new
  users/devices.
* The remaining collections all have per-user syncgroups, where members are
  the user (all of the user’s devices) and "bluebottle":
    * "users" - user RWA, “bluebottle” R (this may have to be relaxed to RW
      for signatures to work correctly)
    * "draftOrders" - user RWA, “bluebottle” no access (this can be relaxed
      if needed for cloud sync functionality, at the expense of privacy)
    * "placedOrders" - user RW, “bluebottle” RWA (user writes when placing
      an order, “bluebottle” deletes when marking order as processed)
    * "processedOrders" - user R, “bluebottle” RWA

In all cases, both "bluebottle" and user can have syncgroup admin (sgA)
permissions to make adding new devices more flexible.

# Conflicts

* Items in catalog: last-writer-wins. (Per-field last-writer-wins would be better.)
  Conflicts should be rare since users can’t write this data, but are possible
  if multiple admins modify catalog items concurrently.
* User records: last-one-wins. (Per-field last-one-wins would be better.)
* Order records: should never have conflicts, given the fields. Delete (i.e.
  as part of placing an order) trumps item-level edits. This would be achieved
  by having item-level edits "touch" the Order object, thus triggering a
  conflict. Hints make it easy to implement the CR callback for this.
  Alternatively, leaving orphaned items and periodically garbage collecting
  them may be simpler.
* OrderItem records: last-one-wins.