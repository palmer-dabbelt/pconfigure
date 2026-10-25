#include "harness_start.bash"

# Every installed file's path is the prefix joined onto its directory
# in one place, context::installed(), so that no install recipe says
# "//" -- which is "the same directory" on Linux, but a network path
# at the front of one on Cygwin and Windows, and a different make
# target from the single-slash spelling everywhere.  A static archive
# builds its install path by hand instead, as "$(DESTDIR)/" + PREFIX
# + "/" + LIBDIR, so it alone installs to "$(DESTDIR)//usr/local/lib"
# and, under "PREFIX = /", to "$(DESTDIR)///lib".  The shared library
# beside it says "$(DESTDIR)/usr/local/lib".
mkdir -p src
echo 'int a(void) { return 1; }' > src/a.c
echo 'int s(void) { return 2; }' > src/s.c

for prefix in "" "PREFIX = /" "PREFIX = /opt/thing"
do
    cat >Configfile <<EOF2
$prefix
LANGUAGES += c

LIBRARIES += liba.a
SOURCES   += a.c

LIBRARIES += libs.so
SOURCES   += s.c
EOF2

    $PTEST_BINARY $PCONFIGURE_ARGS
    grep -n 'DESTDIR)' Makefile | grep 'lib[as]\.' || true
    if grep -n 'DESTDIR)[^ ]*//' Makefile
    then
        echo "a '//' in an install path under '$prefix'" >&2
        exit 1
    fi
done

# And the archive is installed where the shared library is.
make $MAKE_ARGS DESTDIR=$tempdir/dest install
test -f dest/opt/thing/lib/liba.a
test -f dest/opt/thing/lib/libs.so
