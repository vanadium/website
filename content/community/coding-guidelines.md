= yaml =
title: Coding Guidelines
toc: true
= yaml =

# Code organization

Vanadium is spread across multiple [git repositories]. The [contributor
installation] process arranges these repositories as follows (some repositories
omitted, for brevity):

```
 $JIRI_ROOT
   .jiri_root        # Jiri utils and metadata
     scripts/jiri    # Jiri command-line tool
   devtools          # Contributor tool binaries
   environment       # Platform-dependent configuration
   manifest          # Multi-repo configuration data
   release           # Source code
     go/src/v.io/v23 # Interfaces
     go/src/v.io/x   # Implementation
       devtools      # Contributor tool source code
       lib           # Developer libs
       ref           # Reference implementation of v23
     javascript      # JS interfaces and implementation
     projects        # Example apps
       playground    # Write/build/run v23 code on the web
       browser       # Vanadium namespace browser
       chat          # Chat program
   third_party       # Third-party code
   website           # Source for this site
```

Each repository has a `README.md` file summarizing its purpose. The `devtools`
directory isn't a repository, but rather a top-level directory where contributor
tools are placed during installation. The `manifest` repository contains the
configuration that describes this repository arrangement.

Things move around, so its best to examine your local installation for the
latest arrangement.

<!--
TODO:
- Suggestions for how to name things (hyphens vs. underscores).
- Using optional arguments: variadic functions / varargs vs. Options structs.
-->

# Go

Use [gofmt] and suggestions from [Effective Go].

## Interfaces

Vanadium interfaces are defined in the [`go/src/v.io/v23`][v23 code]
tree in files named `model.go`.  For example, the file
[`security/model.go`][security model] holds security interface
definitions.

## Testing

A test for package `foo` should be in package `foo_test`. This way, tests can
depend on anything they like without introducing cycles or affecting non-test
binaries.

If a test must touch the internals of some package `foo`, that test can be in
package `foo`, but must keep its dependencies to a minimum, and must have a name
that ends with `_internal_test.go`.

Most tests should import the [`v.io/x/ref/test` package][test package]
and invoke its [`Init` function][test init] in order to configure
logging, random number generators etc. Doing so will assist in
debugging failing tests. For example:

  * The `-vv` and `-vmodule` flags can be used to control logging verbosity
  * The seed of the random number generator is logged when running tests. This
    is useful when trying to reproduce failures that may not occur when the
    random number generator is seeded differently.

<!-- TODO: Explain modules, expect, timekeeper? -->

<!-- TODO: Describe dependency management (apis vs. impls, what can depend on
what). -->

# VDL

The `devtools/bin/vdl` tool uses VDL files to generate files
containing [RPC] stub code for various languages - Go, Java, JavaScript,
etc.

[VDL] is not Go, but is modeled after Go, so VDL code should follow
Go's style guidelines.

VDL files have a [Go-like notion of packages][packages].  Go code
generated from a VDL file must appear in a location that respects both
the VDL file's package name and the value of `GOPATH`.  In a Go-based
project like Vanadium, the simplest way to accomplish this is to place
VDL source files into the `go/src` tree at the location that the
generated Go should be placed.

# JavaScript

Follow the [Node.js Style Guide]. Use our [.jshintrc].

<!-- TODO: Documentation generation (jsdoc). -->

# Shell

We prefer Go programs over shell scripts for jobs traditionally given
to shell scripts.

If you must write a shell script, follow the
[Google Shell Style Guide].

[.jshintrc]: https://github.com/vanadium/js/blob/master/.jshintrc
[Effective Go]: http://golang.org/doc/effective_go.html
[Google Shell Style Guide]: https://google-styleguide.googlecode.com/svn/trunk/shell.xml
[Node.js Style Guide]: https://github.com/felixge/node-style-guide
[RPC]: /glossary.html#remote-procedure-call-rpc-
[VDL]: /glossary.html#vandium-definition-language-vdl-
[brad talk]: http://talks.golang.org/2014/gocon-tokyo.slide#36
[git repositories]: https://github.com/vanadium
[gofmt]: https://golang.org/cmd/gofmt/
[packages]: https://golang.org/doc/code.html#PackagePaths
[v23 code]: https://github.com/vanadium/go.v23
[security model]: https://github.com/vanadium/go.v23/blob/master/security/model.go
[test package]: https://github.com/vanadium/go.ref/tree/master/test
[test init]: https://github.com/vanadium/go.ref/blob/master/test/init.go
