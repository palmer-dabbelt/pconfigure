#include "harness_start.bash"

# Every install and uninstall recipe pastes $(DESTDIR) into the shell
# as a bare word, so any character the shell reads as syntax rather
# than as part of a path decides what the recipe does.  A '"' or a '`'
# opened a string that never closed, and a '<', '>' or ')' stopped on
# a syntax error or redirected the copy somewhere else -- each of them
# a complaint about a line of the generated Makefile that never says
# DESTDIR was the problem.  A DESTDIR with a ':' or a space in it is
# refused with a sentence naming it; these get the same, and nothing
# is created on the way.
mkdir -p src include
echo 'int main(void) { return 0; }' > src/main.c
printf '#!/bin/bash\necho hi\n' > src/script.bash
echo 'int f(void);' > include/main.h

cat >Configfile <<'EOF2'
LANGUAGES += c
LANGUAGES += bash

BINARIES  += main
SOURCES   += main.c

BINARIES  += script
SOURCES   += script.bash

HEADERS   += main.h
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

for c in '"' '`' '<' '>' ')'
do
    destdir="$tempdir/stage${c}x"
    if make $MAKE_ARGS DESTDIR="$destdir" install > install.out 2>&1
    then
        cat install.out
        exit 1
    fi
    cat install.out
    grep -F "DESTDIR=\"$destdir\"" install.out
    test ! -e "$destdir"
    test ! -e "$tempdir/stage"
    test ! -e "$tempdir/x"

    if make $MAKE_ARGS DESTDIR="$destdir" uninstall > uninstall.out 2>&1
    then
        cat uninstall.out
        exit 1
    fi
    cat uninstall.out
    grep -F "DESTDIR=\"$destdir\"" uninstall.out
done
