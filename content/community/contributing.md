= yaml =
title: Contributing
toc: true
= yaml =

# Reporting issues

We use GitHub for tracking Vanadium issues:
https://github.com/vanadium/issues/issues

# Contributor setup

## Vanadium installation

Follow the [installation instructions] to set up a `JIRI_ROOT` directory and
fetch all Vanadium repositories.

The instructions below assume you've set the `JIRI_ROOT` environment variable
and have added `$JIRI_ROOT/devtools/bin` to your `PATH`:

    # Edit to taste.
    export JIRI_ROOT=${HOME}/vanadium
    export PATH=$PATH:$JIRI_ROOT/devtools/bin

Recommended: Add the lines above to your `~/.bashrc` or similar.

## Contributor license agreement (CLA)

Before patches can be accepted, contributors must sign the Google Individual
[Contributor License Agreement (CLA)][cla], which can be done online. The CLA is
necessary since contributors own the copyright to their code, even after it
becomes part of the codebase, so permission is required to use and distribute
that code. Contributors don't have to sign the CLA until after a patch has been
submitted for review and a member has approved it, but the CLA must be signed
before the patch is committed into the codebase.

Contributions made by corporations are covered by a different agreement than the
one above, the [Software Grant and Corporate Contributor License
Agreement][corp-cla].

## Credentials

To send code reviews and commit changes, you must create an account on
vanadium.googlesource.com:

1. Go to https://vanadium.googlesource.com, log in with your identity, click on
   "Generate Password", and follow the instructions to store the credentials for
   accessing vanadium.googlesource.com locally.
2. Go to https://vanadium-review.googlesource.com and log in with your identity.
   This will create an account for you in the code review system.

## Proposing a change

Before starting work on a large change, we recommend that you [file an
issue][issue tracker] with your idea so that other contributors and authors can
provide feedback and guidance. (For small changes, this is not necessary.)

## Making a change

All of the individual Vanadium projects use [Git] for version control. The
"master" branch of each local repository is reserved for tracking the remote
https://vanadium.googlesource.com counterpart. All Vanadium development should
take place on a non-master (feature) branch. Once your code has been reviewed
and approved, it will be merged into the remote master via our code review
system and brought to your local instance via `jiri update`.

**The only way to contribute to master is via the Gerrit code review process.**

To submit a change for review you will need to squash your feature branch into a
single commit and send the patch to [Gerrit] for code review. The [jiri] tool,
in particular the `jiri cl` command, simplifies this process.

### Creating a change

1. Sync the master branch to the latest version of the project.

        jiri update

2. Create a new branch for your change.

        # Replace `<branch>` with your branch name.
        jiri cl new <branch>

3. Make modifications to the project source code.
4. Stage any changed files for a commit.

        git add <file1> <file2> ... <fileN>

5. Commit your modifications.

        git commit

6. Repeat steps 3-5 as necessary.

### Syncing a change to the latest version of the project

1. Update all of the local master branches using the `jiri` command.

        jiri update

2. If you are not already on it, switch to the feature branch that corresponds
   to the change you are trying to bring up to date with the upstream.

        git checkout <branch>
        git merge master

3. If there are no conflicts, you are done.
4. If there are conflicts:

   * Manually resolve the conflicting files.
   * Stage the resolved files for a commit with `git add <pathspec>...`.
   * Commit the resolved files with `git commit`.

### Requesting a review

1. Switch to the branch that corresponds to the change in question.

        git checkout <branch>

2. Submit your change to Gerrit with the `jiri cl` command.

        # <reviewers> is a comma-seperated list of emails or LDAPs
        # Alternatively reviewers can be added via the Gerrit UI
        jiri cl mail -r=<reviewers>

If you are not sure who to add as a reviewer, you can leave off the `-r` flag.
Our team periodically scans for unassigned CLs and a reviewer will be added to
your CL. If you would rather not wait, feel free to let us know about your
change by filing an issue on GitHub.

### Reviewing a change

1. Follow the link you received in an email notifying you about a review
   request.
2. Add comments as you see fit.
3. When you are finished, click on the "Reply" button to submit your comments,
   selecting the appropriate score.

### Addressing review comments

1. Switch to the branch that corresponds to the change in question

        git checkout <branch>

2. Modify and commit code as as described [above](#creating-a-change).
3. Be sure to address each review comment on Gerrit.
4. Once you have addressed all review comments be sure to reply at the top of
   the Gerrit UI for the specific patch.
5. Once you have addressed all review comments, you can update the change with a
   new patch using:

        jiri cl mail

### Submitting a change

1. Work with your reviewers to receive "+2" score. If your change no longer
   applies cleanly due to upstream changes, the reviewer may ask you to rebase
   it. You will need to follow the steps in the section above: ["Syncing a
   change to the latest version of the
   project"](#syncing-a-change-to-the-latest-version-of-the-project) and then
   run `jiri cl mail` again.
2. The reviewer will submit your change and it will be merged into the master
   branch.
3. Optional: Delete the feature branch once it has been submitted:

        git checkout master
        jiri cl cleanup <branch>

### Useful shortcuts

There are several useful shortcuts you can use for quick access to changes and
issues.

*  [v.io/issues](https://v.io/issues): Takes you to the issues list.
*  v.io/i/[num]: Takes you to a specific issue.
*  [v.io/i/new](https://v.io/i/new): Creates a new issue.
*  [v.io/review](https://v.io/review): Takes you to your review dashboard.
*  v.io/c/[num]: Takes you to the review for a specific change.

[installation instructions]: ../installation/
[cla]: https://cla.developers.google.com/about/google-individual?csw=1
[corp-cla]: https://cla.developers.google.com/about/google-corporate?csw=1
[issue tracker]: https://github.com/vanadium/issues/issues
[git]: http://git-scm.com/
[gerrit]: https://vanadium-review.googlesource.com
[jiri]: ../tools/jiri.html
