#include "harness_start.bash"

# A new PREFIX is a new answer for every "prefix=" line a .pc
# template has, and lib/pkgconfig/x.pc is the copy that answers it
# with the PREFIX: it is what "make" builds, and what an install
# under the old prefix put in place.  The prefix is only in the
# recipe, though, and make doesn't rerun a rule whose recipe changed
# -- so after reconfiguring for /opt/new the tree kept a .pc saying
# /opt/old, while every compiled program was rebuilt to say /opt/new.
mkdir -p src

cat >src/x.pc <<'EOF2'
prefix=@@pconfigure_prefix@@
Name: x
Description: x
Version: 1
EOF2

cat >Configfile <<'EOF2'
PREFIX       = /opt/old
LANGUAGES   += pkgconfig
LIBRARIES   += pkgconfig/x.pc
SOURCES     += x.pc
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
grep -q "^prefix=/opt/old$" lib/pkgconfig/x.pc

sleep 1
sed -i.bak 's@/opt/old@/opt/new@' Configfile
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
cat lib/pkgconfig/x.pc
grep -q "^prefix=/opt/new$" lib/pkgconfig/x.pc

# And the copy that goes under the new prefix says so too.
make $MAKE_ARGS DESTDIR=$tempdir/dest install
grep -q "^prefix=/opt/new$" dest/opt/new/lib/pkgconfig/x.pc
