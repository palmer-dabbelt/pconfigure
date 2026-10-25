#include "harness_start.bash"

# "--srcpath" says where the sources are when the build happens
# somewhere else, the way "../src/configure" does for autoconf.  A
# misspelled one -- a directory that isn't there -- used to read no
# Configfile at all, because a Configfile that isn't there is read as
# an empty one, and so pconfigure wrote an empty Makefile in the build
# directory and exited 0.  "make" then said there was nothing to do.
#
# autoconf's answer to the same mistake is "cannot find sources": a
# source tree that isn't there can't be an empty project, it's a path
# that's wrong.  This expects it to be refused, naming the path, and
# to leave no Makefile behind for a later "make" to find.
mkdir -p build

if (cd build && $PTEST_BINARY $PCONFIGURE_ARGS --srcpath ../no-such-checkout) >out 2>&1
then
    cat out
    exit 1
fi
cat out
test ! -e build/Makefile
grep -q "no-such-checkout', which doesn't exist" out
