= yaml =
title: Brokerage
layout: syncbase
toc: false
= yaml =

# Functionality

The Brokerage app allows a user to invest in the stock market and monitor the
performance of the portfolio.  Security is of utmost importance.
The portfolio can be browsed while offline.  Some non-critical data
(e.g., stock watchlist) may be shared in read-only mode with other apps.
There is no sharing between user accounts.

## Key Behaviors
* Portfolio and transaction data is available for offline access.
* The brokerage firm’s server takes real-world financial actions on behalf of the client and acts as a bridge between the brokerage firm’s backend systems (and databases) and the user’s objects in the Vanadium store.
* The server is the source of truth and the maintainer of the portfolio and the history of transactions.  The client app cannot modify the portfolio directly (only display it), it can only submit new transactions for the server to validate, accept or reject, and act upon.  The client may also try to cancel a transaction if it is still pending, but the server determines the outcome, accepting or rejecting the cancellation request.
* Transactions can be initiated while offline but they only get acted upon when the server learns about it, directly from the initiating client, or indirectly from other peer clients that relayed the transaction to the server.
* The object’s VOM values of critical objects are encrypted in the store using a shared secret per user.  Store queries are thus limited to object keys.
* A transaction object goes through state mutations enforced by the app and the server:
  * Client creates a transaction in “open” state.
  * Client moves a transaction to “submitted” state to trigger server action on it.
  * Server moves a transaction to “accepted” state to indicate it is now official.
  * Server moves a transaction to “done” (purchase or sale completed), “rejected”, or “cancelled” states.
  * Client may move a transaction to “cancel” state while still in “submitted” or “accepted” states.
  * The server resolves race conditions in state transitions (e.g. cancel or done) and the server is the source of truth.  This means business logic is needed at the server for conflict resolution, the default policies are not sufficient.
* Portfolio updates are transactional across objects and across collections: add shares, remove cash, and update the status of the financial transaction (remove it from the “Transactions” collection, insert a historical record in the “Portfolio” under the “Completed-Transactions” directory.
* Transactions are ordered by their visibility at the server, the local creation time at the client is only informational.
* Security prices are updated by the server (e.g. periodically while the market is open for that security).
* The watchlist is a shared read-only copy of the updated stock prices, created locally by the app in a separate directory, based on the security prices received from the server.  The app may update this copy at a slower frequency than the server’s updates of the security prices.
* User confusion when issuing dependent transactions from different devices, some online and some offline, is their own problem and may result in transactions being rejected (e.g. lack of funds).  The state of the portfolio at the server is always valid and the time ordering of transactions at the server is compatible with the portfolio state.
* All critical objects are only accessible by the <user>/<app> and <app-server>/<user> principals.
* Non-critical objects used for cross-app sharing are not encrypted and have read-only access for a selected list of <user>/<other-app> principals chosen by the user.  For this to work the shared object schemas have to be known by these apps and modified in future versions in cross-app backward-compatible manner.  It might be easier for app developers to skip that and rely on APIs for cross-app data sharing.
* For extra safety, when a transaction reaches a terminal state (done, rejected, cancelled) the server makes it read-only.

# Schema

## Data Types

```Go
// The IDs are store keys.
type SecurityID string
type BatchID string
type TxID string
type TxState int
type TxType int

const Cash = SecurityID(“Cash”)
const NoBatch = BatchID(“”)

const (
  Open TxState = iota
  Submitted
  Accepted
  Done
  Rejected
  Cancel
  Cancelled
)

const
  Buy TxType = iota
  Sell
  Dividend
  ShortTermCapGain
  LongTermCapGain
  Interest
  // other complicated transaction types...
)

type AssetBatch struct {
  ID BatchID
  Security SecurityID
  NumShares int32
  Price float32
  Date int64
}

type Transaction struct {
  ID TxID
  State TxState
  Type TxType
  Security SecurityID
  NumShares int32
  FromBatch BatchID // when selling
  DateOpened int64
  DateAccepted int64
  DateClosed int64  // done, rejected, cancelled
}

type SecurityMeta struct {
  Security SecurityID
  Name string
  // other quasi-static info...
}

type SecurityPrice struct {
  Price float32
  Date int64
}

type WatchlistEntry struct {
  Security SecurityID
  Name string
  Price float32
  Date int64
}
```

## Organization

```
Collection <deckId>
Brokerage/
  <user>/              // database
    Portfolio/         // collection (user: R, server: RW)
      Assets/
        <security-ID>/
          <batch-ID>   // type AssetBatch
      Completed-Transactions/
        <tx-ID>        // type Transaction
      Securities/
        <security-ID>/
          metadata     // type SecurityMeta
          price        // type SecurityPrice
    Transactions/      // collection (user: RW, server: RW)
      <tx-ID>          // type Transaction
    Shared/            // collection (user: RW)
      Watchlist/
        <security-ID>  // type WatchlistEntry
```

There is one app database (“Brokerage/<user>”) with 3 collections each with a syncgroup:
* “Portfolio”: joined by all the user’s devices (read-only) and the brokerage firm’s server (read-write).  It also contains completed transactions, a read-only historical record.
* “Transactions:” joined by all the user’s devices (read-write) and the brokerage firm’s server (read-write).  These are the inflight transactions created by the user and not yet finalized by the server.
* “Shared”: joined by the user’s devices (read-write) and is locally managed by the app without involving the firm’s server.

In the “Transactions” collection, the user writes or updates objects in these cases:
* Create a transaction.
* Cancel a transaction.

Some transaction types cannot be entered by the user, they exist for the server to report automatically created transactions (e.g. dividends).

During app-to-app synchronization, the peers accept each other’s data based on the default last-timestamp-wins policy.

# Conflicts

During app-to-server synchronization, the server code handles its own conflict resolution, after decrypting the objects, applying business rules, and validating changes transactionally with the firm’s databases.  It rejects invalid transactions, decides whether a “cancel” arrived before the transaction was done, and updates the objects under the “Assets” directory.  The server also updates the objects under the “Securities” directory, filling the security metadata if needed, and updating the security prices.