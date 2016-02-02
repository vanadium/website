= yaml =
title: JavaScript Prerequisites
toc: true
sort: 3
= yaml =

JavaScript development requires the `nacl` and `nodejs` profiles. As an
additional prerequisite, OS X users must have a full and up-to-date installation
of Xcode.

Install `nacl` and `nodejs` profiles:

    jiri v23-profile install nacl nodejs

Build and test the JavaScript code:

    cd $JIRI_ROOT/release/javascript/core
    make test

Remove all JavaScript build artifacts:

    make clean
