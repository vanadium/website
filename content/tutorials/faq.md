= yaml =
title: Tutorial FAQ
layout: tutorial
toc: true
enumerable: false
= yaml =

# Do I need to know Go?

No. The initial coding tutorials use short, unexotic blocks of Go that
should be readable by anyone familiar with a language in the C family.

For Go specific tutorials, see [golang.org].

# Must the tutorials be done in order?

No. Some tutorials assume familiarity with things covered in previous
tutorials, and some literally depend on files created in previous tutorials
but have instructions on how to get these without having to step through the
tutorials that generate them.

Every tutorial begins with a __Prerequisites__ section specifying a
_completer_ script to download and `source` in your active shell.
Running a script called `foo-completer.sh` runs the same commands
you'd run if you manually performed the `foo` tutorial _and its
preceding tutorials_ in the order needed to create the desired state.

# Why Bash?

Bash works out of the box on both Linux and OS X.

The tutorials (and installation instructions, etc.) consist of small
bash command blocks, interspersed with explanation about the blocks
and their expected effect.

You're expected to execute those blocks in a terminal on a local
machine, to manipulate local code, tools, configuration, servers, etc.
The blocks have __[Copy to clipboard]__ buttons to facilitate this.

If you normally use another shell, just execute bash command blocks
in a bash subshell.

# Why 'source'?

You'll sometimes be asked to run [bash scripts] using the syntax

> `source foo.sh`

This syntax allows the script to consult or set the environment of the
_active shell_.  Syntax that implicitly runs scripts in _a transient
subshell_ (e.g. piping to `source`, entering `bash foo.sh`, etc.)
defeats this goal.

# Where is the source code?

The command blocks presented on tutorial pages are the __canonical source__ of
those blocks. The source for the pages lives in the [vanadium/website]
repository's content directory.

All code files (Go, [VDL], js, etc.), are defined using bash command
blocks that also _display_ those code files embedded in their
commentary.

The advantages of this over keeping the code in a distinct (code-only)
location include:

* Less document/code rot.

  Identifiers, file names and discussion referring to them all live in
  the same document.  Easy to keep stuff in sync.

* Natural buildup.

  The reader builds programs file by file in a particular order,
  rather than being immediately presented with a large repository
  clone supporting some maximally complex end state.

Bash [HERE documents], in conjunction with `cat` commands, manage local
file placement.  Single-space indentation on `cat` commands keep very
long commands out of your command history.

A test framework regularly extracts command blocks from these pages
and executes them, failing on any error.  Library changes that would
break the tutorials must be accompanied by tutorial content changes
that keep things up to date.

# Do I need to know JavaScript to do the JavaScript tutorials?

The JavaScript tutorials describe Vanadium concepts from a JavaScript
perspective. Familiarity with the language is helpful but is not required.

# Where are the API docs?

Please refer to our in-depth [API references].

# What is the Vanadium Chrome extension?

Please refer to the
[Vanadium Chrome extension] page.

# How can the JavaScript tutorials be run in Node.js?

The JavaScript tutorials are designed for the browser and interact with web
pages. They can be adapted to a pure `node` environment by removing the
web-specific components.

Vanadium Node.js programs currently require a go-language proxy `wsprd`
(Websocket Proxy Daemon) to be running. `wsprd` performs the same role as the
[Vanadium Chrome extension]. It is our intention to remove these requirements
so that running `npm install` is the only step needed to use Vanadium.

To start `wsprd`, run:

```
$V_BIN/wsprd \
  -v23.namespace.root /\(dev.v.io/role/vprod/service/mounttabled\)@ns.dev.v.io:8101 \
  -v23.proxy proxy \
  -identd identity/dev.v.io/u/google
```

The above flags give the `node` program the same blessings and namespace root as
the tutorial examples running in the browser.

The Vanadium program will also need to know where `wsprd` is running. By default,
this is at `http://127.0.0.1:8124`. (It can be customized with the
`v23.tcp.address` flag.) Add the `wspr` field to your Vanadium configuration:

```
var config = {
  wspr: http://127.0.0.1:8124,
};
```

[VDL]: /glossary.html#vanadium-definition-language-vdl-
[golang.org]: http://golang.org/
[bash scripts]: #why-bash-
[HERE documents]: http://tldp.org/LDP/abs/html/here-docs.html
[vanadium/website]: https://github.com/vanadium/website
[API references]: /docs.html
[Vanadium Chrome extension]: /tools/vanadium-chrome-extension.html
