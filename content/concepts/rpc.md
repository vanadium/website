= yaml =
title: RPC System
sort: 1
toc: true
= yaml =

The Vanadium remote procedure call ([RPC]) system enables [communication]
between processes by presenting an API based on local function calls.  Function
calls are a familiar model to developers, and the API hides low-level details
like the underlying network transport and data serialization protocols.

# Basics

There are two participants in RPC-based communication.  The caller of an RPC is
known as the **client** and the receiver that implements the RPC is known as the
**server**.  A single device may often behave as a client for some operations,
and as a server for other operations.

An example of a simple RPC:
```
  Divide(x, y int32) (quotient, remainder int32 | error)
```

The client calls `Divide` like a regular function, providing two integer input
arguments `x` and `y`.  The server implements `Divide` and returns either the
result of `x/y` as two integer output arguments `quotient` and `remainder`, or
an error.  Notice that errors may always occur, e.g. the client may be unable to
contact the server if the server isn't running.  Every RPC includes the
possibility of returning an error rather than the specified output arguments.

An example of a streaming RPC:
```
  Print(format string) stream<int32, string> (string | error)
```

The client calls `Print` and provides a single string argument `format`.
Thereafter the client may stream zero or more integer arguments to the server,
and the server will reply with the string representation of that argument.  When
the operation is finished, the server responds with a string containing any
final output.  The input and output arguments behave identically to the
non-streaming example.

The streaming arguments are transferred after the input arguments are sent from
client to server, and before the output arguments are sent from server to
client.  The exact protocol for the streaming arguments is determined by the
application; supported modes include client to server streaming for uploads,
server to client streaming for downloads, as well as bi-directional streaming
for other use cases.

The RPC system takes care of the underlying protocols necessary for all of these
forms of communication.

# VDL

The Vanadium Definition Language (VDL) enables interoperability between software
components executing in different computing environments. For example, an Android application written in Java running on a mobile phone may wish to
communicate with a backend written in Go running in the cloud.

VDL has a well-defined type system and semantics that specify the baseline
behavior for all RPCs.  Each native computing environment or programming
language has a mapping between native concepts and VDL.  Specifying application
level RPC protocols in terms of VDL enables clients and servers to be easily
written for any supported environment.

VDL can define four different entities:

**Interfaces** contain methods that can be invoked via RPCs.
```
// Restaurant contains methods to order items of food,
// and to check their price without ordering.
type Restaurant interface {
  // Order orders the item of food, and returns its price.
  Order(item Food) (Price | error)
  // Price returns the price for the item of food.
  Price(item Food) (Price | error)
}
```
**Types** define data sent via RPC.
```
// Food enumerates the available food items.
type Food enum {
  Pizza
  Pasta
  Calzone
}
// Price represents the price of a food item.
type Price uint16
```
**Constants** to hold fixed data used by the application protocol.
```
// StandardPrices holds standard fixed prices for each
// food item.
const StandardPrices map[Food]Price{
  Pizza: 10, Pasta: 8, Calzone: 9,
}
```
**Errors** that may be returned from failing RPCs, with support for
internationalization of the error messages.
```
// MissingIngredients is returned when a food item is
// unavailable, because an ingredient is out of stock.
error MissingIngredients(ingredientName string) {
  "en" : "{ingredientName} is out of stock"
}
```

For more details see the [VDL specification].

# VOM

The Vanadium Object Marshalling (VOM) format is the underlying serialization
format used by the RPC system.  VOM supports serialization of all types
representable in VDL. It is a self-describing protocol that retains full type
information when transmitting values and, in particular, retains type
information for all method arguments.

For more details see the [VOM specification].

[RPC]: http://en.wikipedia.org/wiki/Remote_procedure_call
[communication]: http://en.wikipedia.org/wiki/Inter-process_communication
[VDL specification]: /designdocs/vdl-spec.html
[VOM specification]: /designdocs/vom-spec.html
