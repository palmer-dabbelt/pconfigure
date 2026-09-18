#include "harness_start.bash"

mkdir -p src/std

##############################################################################
# A header with no extension is still a header                               #
##############################################################################
# Every header the C++ standard library has is spelled without one --
# <queue>, <vector>, <cstdint> -- so a project shipping a header that
# stands in for one of those has to install it under exactly that
# name.  There is nowhere for an extension to go.
#
# The "h" language decided what it could take by looking at the
# extension, so such a header matched nothing and pconfigure stopped
# with "Unable to find language for".  What was left was a HEADERS
# with no SOURCES under it, which is a different thing: it reads the
# file out of the include directory rather than copying one there,
# and then cleans it up again as something the build produced.
cat >Configfile <<EOF
LANGUAGES += c
LANGUAGES += h

HEADERSRC += std/queue
EOF

cat >src/std/queue <<EOF
#ifndef SHIM_QUEUE
#define SHIM_QUEUE

#include <stddef.h>

int queue_depth(size_t n);

#endif
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

make $MAKE_ARGS

# Copied into the include directory under the name it installs as, so
# that anything compiled against this build finds it by that name.
diff -u src/std/queue include/std/queue

make $MAKE_ARGS DESTDIR=$(pwd)/install install
diff -u src/std/queue install/usr/local/include/std/queue

# Byte for byte, both times.  This goes through phc rather than
# pbashc, and pbashc would have taken the #include out and put a
# "#!/bin/bash" on the front.
grep -q "#include <stddef.h>" install/usr/local/include/std/queue
if head -1 install/usr/local/include/std/queue | grep -q "^#!"
then
    exit 1
fi

##############################################################################
# And cleaning takes back the copy rather than the original                  #
##############################################################################
# This is the half that makes the spelling above worth having.  The
# source is a file somebody wrote and the copy is one the build made,
# so only one of them is the build's to remove.
make $MAKE_ARGS distclean

test -f src/std/queue
if test -f include/std/queue
then
    exit 1
fi

exit 0
