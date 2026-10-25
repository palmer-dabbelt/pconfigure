#include "harness_start.bash"

# A staging directory named after the time it was made has a colon in
# it, and a ';' is just as legal in a directory name.  Every installed
# file is a make target named "$(DESTDIR)/...", though, and in a rule
# make ends the targets at the first ':' and the prerequisites at the
# first ';'.  "make DESTDIR=/tmp/stage-12:30 install" stopped on
# "target pattern contains no '%'" and a ';' on "missing separator":
# both name a line of the generated Makefile and neither says a word
# about DESTDIR, so the packager is left to work out which of their
# variables the Makefile choked on.  Whitespace in a DESTDIR is refused
# with a sentence saying what is wrong and what to do instead; these
# break the target names the same way and get the same.
mkdir -p src include
echo 'int main(void) { return 0; }' > src/main.c
printf '#!/bin/bash\necho hi\n' > src/script.bash
echo 'int f(void);' > include/main.h

cat >Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash

BINARIES  += main
SOURCES   += main.c

BINARIES  += script
SOURCES   += script.bash

HEADERS   += main.h
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

for destdir in "$tempdir/stage-12:30" "$tempdir/stage;x"
do
    if make $MAKE_ARGS DESTDIR="$destdir" install > install.out 2>&1
    then
        cat install.out
        exit 1
    fi
    cat install.out
    grep -F "DESTDIR=\"$destdir\"" install.out
    test ! -e "$destdir"

    # The uninstall rules are spelled out of the same words, so the
    # same explanation has to stop them too.
    if make $MAKE_ARGS DESTDIR="$destdir" uninstall > uninstall.out 2>&1
    then
        cat uninstall.out
        exit 1
    fi
    cat uninstall.out
    grep -F "DESTDIR=\"$destdir\"" uninstall.out
done

# What the message suggests instead -- a spelling of the same
# directory without the colon -- installs into the one that has it.
mkdir "$tempdir/stage-12:30"
ln -s "$tempdir/stage-12:30" "$tempdir/stage-link"
make $MAKE_ARGS DESTDIR="$tempdir/stage-link" install
test -x "$tempdir/stage-12:30/usr/local/bin/main"
test -x "$tempdir/stage-12:30/usr/local/bin/script"
test -f "$tempdir/stage-12:30/usr/local/include/main.h"
