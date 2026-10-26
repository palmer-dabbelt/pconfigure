#include "harness_start.bash"

# A trailing '/' on a BINARIES name is dropped, so "main/" builds
# "bin/main".  The same slash on a HEADERS name was kept: the install
# rule was for "$(DESTDIR)/usr/local/include/sub/a.h/" with a
# prerequisite of "include/sub/a.h/", which no file can be, and "make
# install" stopped on "No rule to make target".  It adds nothing a
# header's name could mean either, so it is dropped here too and the
# header is installed and uninstalled under the name without it.
mkdir -p include/sub
echo 'int a;' > include/sub/a.h

cat >Configfile <<'EOF2'
LANGUAGES += c
HEADERS   += sub/a.h/
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS

make $MAKE_ARGS DESTDIR=$tempdir/dest install
cmp include/sub/a.h dest/usr/local/include/sub/a.h
make $MAKE_ARGS DESTDIR=$tempdir/dest uninstall
test ! -e dest/usr/local/include/sub/a.h
