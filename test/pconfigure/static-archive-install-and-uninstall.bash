#include "harness_start.bash"

# A static archive is installed like any library: the same archive the
# tree's lib/ gets, under $(DESTDIR)$PREFIX/lib, nested name and all,
# and taken back out by "make uninstall".  There's no install-flavoured
# link of an archive the way there is of a shared library, since an
# archive has no RUNPATH to point anywhere, so the installed copy is
# byte for byte the one in the tree.
mkdir -p src
echo 'int a(void) { return 1; }' > src/a.c
echo 'int b(void) { return 2; }' > src/b.c

cat >Configfile <<'EOF2'
PREFIX     = /opt/thing
LANGUAGES += c

LIBRARIES += liba.a
SOURCES   += a.c

LIBRARIES += sub/libb.a
SOURCES   += b.c
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
make $MAKE_ARGS DESTDIR=$tempdir/dest install

find dest -type f
cmp lib/liba.a dest/opt/thing/lib/liba.a
cmp lib/sub/libb.a dest/opt/thing/lib/sub/libb.a
test -n "$(ar t dest/opt/thing/lib/liba.a)"

make $MAKE_ARGS DESTDIR=$tempdir/dest uninstall
find dest -type f > left
cat left
test ! -s left

# Uninstalling is about the copies under the prefix.
test -f lib/liba.a
test -f lib/sub/libb.a
