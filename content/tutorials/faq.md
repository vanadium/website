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

# Where are the API docs?

Please refer to our in-depth [API references].

# What is the Vanadium Chrome extension?

Please refer to the
[Vanadium Chrome extension] page.

[VDL]: /glossary.html#vanadium-definition-language-vdl-
[golang.org]: http://golang.org/
[bash scripts]: #why-bash-
[HERE documents]: http://tldp.org/LDP/abs/html/here-docs.html
[vanadium/website]: https://github.com/vanadium/website
[API references]: /api-reference.html
[Vanadium Chrome extension]: /tools/vanadium-chrome-extension.html
