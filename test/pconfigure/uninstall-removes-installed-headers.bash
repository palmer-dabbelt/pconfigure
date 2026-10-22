#include "harness_start.bash"

##############################################################################
# A header "make install" put in place is one "make uninstall" removes      #
##############################################################################
# The manual's whole description of "make uninstall" is that it
# removes every target "make install" created.  A header is installed
# by phc rather than by the cp rule a compiled program gets, and that
# cp rule was the only install rule that registered itself with
# "uninstall" -- so a header went in and then stayed there, under a
# nested name and a flat one alike, beside the library that had been
# taken out from next to it.
mkdir -p include/sub/deeper src/std
echo 'int a;' > include/sub/deeper/a.h
echo 'int b;' > include/b.h
echo 'int f(void) { return 0; }' > src/f.c

# A header with no extension goes through the explicit "h" language
# rather than the implicit one the two above get, and its install rule
# is written by a different file.  Both have to be on "uninstall", so
# both are here.
echo 'int queue_depth(void);' > src/std/queue

cat >Configfile <<EOF
LANGUAGES += c

HEADERS   += sub/deeper/a.h
HEADERS   += b.h

LIBRARIES += libf.so
SOURCES   += f.c

LANGUAGES += h

HEADERSRC += std/queue
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
make $MAKE_ARGS DESTDIR=$tempdir/dest install

test -f dest/usr/local/include/sub/deeper/a.h
test -f dest/usr/local/include/b.h
test -f dest/usr/local/include/std/queue
test -f dest/usr/local/lib/libf.so

make $MAKE_ARGS DESTDIR=$tempdir/dest uninstall

# Every file, rather than the ones named above: the point is that
# nothing install wrote survives, and a list of what to look for is a
# list that misses whatever the next install rule adds.
find dest -type f > left
cat left
test ! -s left

# And the originals are still where they were.  An uninstall that
# reached back into the tree it was installed from would pass the
# check above just as well.
test -f include/sub/deeper/a.h
test -f include/b.h
test -f src/std/queue
