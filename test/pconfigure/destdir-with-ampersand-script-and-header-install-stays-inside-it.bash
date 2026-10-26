#include "harness_start.bash"

# The BASH and header install rules are written by different backends
# from the C one (languages/bash.c++ spells its own "mkdir -p
# $(DESTDIR)/usr/local/bin", the header rule hands $(DESTDIR) to phc),
# so a DESTDIR the C rule gets right can still go wrong in them.  With
# an '&' in it -- a checkout under "R&D" -- each of those recipes runs
# the half before the '&' as a background command of its own.  The
# script and the header have to land in the staging directory, or the
# install has to stop naming DESTDIR, and nothing may appear beside
# it.

mkdir -p src include

cat >Configfile <<'EOF2'
LANGUAGES += bash
LANGUAGES += h

BINARIES  += script
SOURCES   += script.bash

HEADERS   += x.h
EOF2

echo 'echo hi' > src/script.bash
echo 'int x(void);' > include/x.h

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

mkdir "R&D"
destdir="$tempdir/R&D/stage"
if make $MAKE_ARGS install DESTDIR="$destdir" > install.out 2>&1
then
    cat install.out
    test -x "$destdir/usr/local/bin/script"
    test -f "$destdir/usr/local/include/x.h"
else
    cat install.out
    grep -F "DESTDIR=\"$destdir\"" install.out
fi

test ! -e R

exit 0
