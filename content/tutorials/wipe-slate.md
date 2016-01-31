= yaml =
title: Internal Tutorial Wipe Slate
layout: tutorial
sort: 98
toc: false
enumerable: false
= yaml =

Clear, but don't delete, the tutorial workspace directory.

Might be used in tests, tutorial preparation, etc.

<!-- @deleteTutdirContent @test @testui @completer -->
```
if [ -z "${V_TUT}" ]; then
  echo "V_TUT not defined, nothing to do."
else
  if [ -d "${V_TUT}" ]; then
    /bin/rm -rf $V_TUT/*
    echo "Removed contents of $V_TUT"
  else
    echo "Not a directory: V_TUT=\"$V_TUT\""
  fi
fi
```
