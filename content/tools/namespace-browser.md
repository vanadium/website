= yaml =
title: Namespace Browser
sort: 1
= yaml =

The Vanadium Namespace Browser is an interactive tool to browse Vanadium
namespaces, find services, and invoke methods on these services. Vanadium
namespaces can be public, in that they are accessible (and thus browsable) to
a large number of users and devices, or they can be private to an individual
or an organization. The Namespace Browser is especially useful for exploring
existing public namespaces, inspecting data in a Syncbase service,
or developing of new Vanadium applications.

The user can specify a mount table, browse through the graph of referenced
mount tables, then see where services are mounted.
The user can select any service to see more detailed information about it.
The user can also interact with the service,
invoking methods to examine or modify the state of the service.

# Running the Namespace Browser
To use the Namespace Browser, run:
```
$JIRI_ROOT/release/projects/browser/run.sh
```
and navigate to [http://localhost:9001/](http://localhost:9001/).

# Getting help
Documentation is available by clicking on the menu icon in
the upper left corner, then selecting "Help".

# GitHub repository
The code repository for the Namespace Browser is on [GitHub](https://github.com/vanadium/browser).
Bugs and other issues can be submitted to the
[Issue Tracker](https://github.com/vanadium/browser/issues).

