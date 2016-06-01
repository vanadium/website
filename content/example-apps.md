= yaml =
title: Example Apps
toc: true
= yaml =

# Vanadium Chat

* Repo: https://github.com/vanadium/chat
* Issues: https://github.com/vanadium/chat/issues

[Vanadium Chat][chat] is a peer-to-peer chat application that demonstrates
common usage patterns for the Vanadium libraries.

There are currently two clients: a [web client] and a Go-based shell client.

For more information, see the [README][chat-readme].

# PipeToBrowser

* Repo: https://github.com/vanadium/pipe2browser
* Issues: https://github.com/vanadium/pipe2browser/issues

[PipeToBrowser][p2b] (P2B) is a Vanadium application that allows users to pipe
anything from a shell to the browser using regular shell piping functionality.
Piped data is displayed in a formatted way by a graphical viewer. Users can also
send or redirect pipes to other users of P2B.

For example, one can pipe a text log file and view it in a sortable, filterable,
paged DataGrid in the browser:

    $ tail -n 100 logfile.txt | p2b google/p2b/myInstance/vlog

As another example, one can pipe an image to someone else's browser:

    $ cat cat.png | p2b google/p2b/myFriendsInstance/image

P2B supports several built-in plugins such as console, image viewer, log viewer,
git status viewer, and `dev/null`. Users can create their own plugins as well.

For more information, see the [README][p2b-readme] as well as the help page
inside a running instance of the P2B application.

[todos]: https://github.com/vanadium/todos
[syncbase]: /concepts/syncbase-overview.html
[todos-readme]: https://github.com/vanadium/todos/blob/master/README.md
[chat]: https://github.com/vanadium/chat
[web client]: https://chat.v.io
[chat-readme]: https://github.com/vanadium/chat/blob/master/README.md
[p2b]: https://github.com/vanadium/pipe2browser
[p2b-readme]: https://github.com/vanadium/pipe2browser/blob/master/README.md
