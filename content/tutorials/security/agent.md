= yaml =
title: The Agent
layout: tutorial
wherein: you use a security agent to maintain your secrets and facilitate your secure use of Vanadium.
prerequisites: {scenario: d}
sort: 25
toc: true
= yaml =

# Motivation

In the [principals tutorial] you used the `principal create` command
to create the _principals_ Alice, Bob, etc.  The operation made
collections of files in the specified target directories, e.g.:

<!-- @lsCredAlice @test -->
```
ls $V_TUT/cred/alice $V_TUT/cred/bob
```

Stored among these files are the private keys associated with Alice
and Bob.  The keys could be encrypted (there are ways to do that), but
at the moment, they aren't.  At no point during earlier tutorials did
you - the tutee - get prompted for a passphrase, despite frequent use
of the `--v23.credentials {directory}` flag.

Using that flag means the given program loads the private key into
process memory as part of its runtime initialization.

This was OK for the tutorials, which had the goal of _teaching_
security concepts rather than _being_ secure.  You were running only
official Vanadium apps or programs that you wrote, in your own
authenticated session, on a machine under your control.

But easy access to the private key is not OK under normal
circumstances. A private key should be private.

Likewise, the way blessings have been generated so far -  in which
you the tutee casually exploited your read access to the private keys
of both the blessor and blessee - isn't practical for blessings being
granted between disjoint principals remote from each other on
a network.

Encrypting the file on disk, and requiring a password with each
invocation of a command specifying `--v23.credentials {directory}`
will solve the immediate problem of a clear text key on disk, but
doesn't solve these other problems.

# An agent holds the key

Part of the solution to these problems is `agentd`, a Vanadium utility
analogous to [`ssh-agent`].  It loads credentials into its memory, and
serves key management requests from child processes.

The child process, needing to check the validity of blessings coming
in with a request, can pass said blessings (implicitly via the
runtime's use of a POSIX [file descriptor]) up to `agentd`, which then
does the necessary crypto with the keys it holds, passing the result
back to the child.

This happens in the Vanadium runtime - no new client code required.

To see that, rerun the _existing_ client code against the _existing_
server code using two instances of the agent - one becomes Alice, the
other becomes Bob.

The only difference between the following command sequence and
[previous usage][previous-usage] is that `agentd` takes the
`--v23.credentials` flag, rather than the client and server.

<!-- @twoAgents @test -->
```
# Clean up from previous attempt, if any.
kill_tut_process TUT_PID_AGENT
/bin/rm -f $V_TUT/server.txt

# Run the server under an agent.
$V_BIN/agentd --v23.credentials $V_TUT/cred/alice \
    $V_TUT/bin/server \
        --endpoint-file-name $V_TUT/server.txt \
        --perms '{"R": {"In": ["alice:family",
                               "alice:friend"]},
                  "W": {"In": ["alice:family"]}}' &
TUT_PID_AGENT=$!
# Wait for startup.
sleep 2s

# Run the client under an agent.
$V_BIN/agentd --v23.credentials $V_TUT/cred/bob \
    $V_TUT/bin/client --server `cat $V_TUT/server.txt`

# All done, kill the server.
kill_tut_process TUT_PID_AGENT
```

The above should run without errors, i.e. the client should report a
fortune.

The crucial new behavior here is that _neither the server nor client
binary had access to private keys_.  The runtime off-loaded all crypto
checks to the agent in a different process (the parent process).

In the normal course of events, where you run code whose source code
you've not written or may not have access to, this is a critical
capability.  The program runs with clear identity, but cannot secretly
send the private keys to that identity elsewhere.

# Become Alice

Use `bash {scriptName}` as the argument to `agentd` to safely
run a script as a given identity.  Here, the script just runs
`principal dump` commands, introspecting its own identity:

<!-- @becomeAlice @test -->
```
cat <<EOF > $V_TUT/subshell.sh
  $V_BIN/principal dump
  $V_BIN/principal get forpeer ... | \
      $V_BIN/principal dumpblessings -
EOF
$V_BIN/agentd --v23.credentials $V_TUT/cred/alice \
    bash $V_TUT/subshell.sh
```

Don't do this now, but say you wanted to spend the day as Alice.  To
interactively issue many commands as a particular Vanadium principal,
just start an agent-wrapped _interactive_ shell:

`$V_BIN/agentd --v23.credentials {directory} bash`

At the time of writing, only the _bash_ shell (not _csh_ or _zsh_)
supports the correct file descriptor forwarding to allow this.


# Alice's vassals

If you're running _as Alice_, and you want to run some program `foo`
with a distinct principal, use `vbecome`:

<!-- @becomeOthers @test -->
```
cat <<EOF > $V_TUT/subshell.sh
  echo " "
  echo "************************ Alice:"
  $V_BIN/principal dump
  echo " "
  echo "************************ Alice's vassal Andy:"
  $V_BIN/vbecome --name andy $V_BIN/principal dump
EOF
$V_BIN/agentd --v23.credentials $V_TUT/cred/alice \
    --additional-principals $V_TUT/cred/alice \
    bash $V_TUT/subshell.sh
```

Compare the output of the two `dump` commands to see that the first
one ran as simply _alice_, while the second, with `vbecome`, ran as
_alice:andy_.

The public keys of the two differ, indicating that the vassal is a
distinct principal.  A use for this behavior would be some manager of
many processes, running each process with a new identity.

Here's the server and client example again, using `vbecome` for the
client.  This example omits the `--name` flag on `vbecome`.  In this
case, `vbecome` uses the name of the executable being run as the blessing
name.  Thus, in this case, the blessing name will be _alice:client_ (the agent
runs as _alice_, and the executable's name is _client_).

<!-- @onceMoreWithFeeling @test -->
```
cat <<EOF > $V_TUT/subshell.sh
  $V_TUT/bin/server \
      --endpoint-file-name $V_TUT/server.txt \
      --perms '{"R": {"In": ["alice:client"]},
                "W": {"In": ["alice:family"]}}' &
  TUT_PID_SERVER=\$!
  sleep 2s # wait for startup
  $V_BIN/vbecome $V_TUT/bin/client \
      --server \`cat $V_TUT/server.txt\`
  kill \$TUT_PID_SERVER # Only making one call.
EOF
$V_BIN/agentd --v23.credentials $V_TUT/cred/alice \
    --additional-principals $V_TUT/cred/alice \
    bash $V_TUT/subshell.sh
```

The RPC works because the client runs with a blessing derived from the
principal running the server - specifically, the client runs with the
blessing `alice:client` (note the server's permissions).


# Secure blessing

[Previous examples of blessing][blessing-example] used a Unix pipe to
transmit a blessing from one process running `principal bless` to some
other process using `principal set forpeer`.

The problem in that is not the blessing being sent 'in the clear' -
that's OK.  The problem is that the person issuing the commands _has
direct access to credential data on both sides_.

The agent, and the command `principal recvblessing`, make the act of
blessing much more secure.

The following example involves two processes, securely running under
distinct agents (neither process can see private keys).

The first process, running as Bob, will get into a state where it
_waits_ for a blessing. The second process, running as Alice, will
send the blessing.

First start Bob.  He'll wait for the blessing, then dump it and exit
as soon as he gets it.

<!-- @receiveBlessing @sleep -->
```
cat <<EOF > $V_TUT/subshell1.sh
  $V_BIN/principal recvblessings \
      --remote-arg-file $V_TUT/recvblessings_args.json
  $V_BIN/principal dump
EOF
$V_BIN/agentd --v23.credentials $V_TUT/cred/bob \
    bash $V_TUT/subshell1.sh &
```

{{# helpers.info }}
The next commands can be run in the same terminal, but you might want to
start a [second terminal] to keep the process output disentangled.
{{/ helpers.info }}

Now run Alice.  Alice will transmit the blessing, using instructions
Bob left her in the file `$V_TUT/recvblessings_args.json`.

<!-- @transmitBlessing @sleep -->
```
cat <<EOF > $V_TUT/subshell2.sh
  echo " "
  echo "Transmitting the blessing."
  $V_BIN/principal bless \
      --for 2h \
      --remote-arg-file $V_TUT/recvblessings_args.json \
      companion
EOF
$V_BIN/agentd --v23.credentials $V_TUT/cred/alice \
    bash $V_TUT/subshell2.sh
```

The `bless` command above transmits the blessing `alice:companion` from
Alice to Bob.  This blessing can be seen in the output of `principal
dump` in the output from Bob's shell.

In this scenario, neither Alice nor Bob nor the principal programs
running on either end had direct access to private keys.  Only the two
agents had the keys.

The file doesn't hold the blessing, it just holds communication
overhead data; see `$V_BIN/principal help recvblessings` for more
info.

# Summary

* Use `agentd` to keep your private keys private.

* Use `vbecome` to seamlessly create a principal for a subprocess, blessed
  by the principal of the existing process.

* Use `principal recvblessing` to send a blessing over the network
  from the command line.

[blessing-example]: /tutorials/security/principals-and-blessings.html#blessings
[principals tutorial]: /tutorials/security/principals-and-blessings.html#principals
[previous-usage]: /tutorials/security/permissions-authorizer.html#a-specific-permissions-map
[file descriptor]: http://en.wikipedia.org/wiki/File_descriptor
[`ssh-agent`]: http://en.wikipedia.org/wiki/Ssh-agent
[second terminal]: /tutorials/setup.html
