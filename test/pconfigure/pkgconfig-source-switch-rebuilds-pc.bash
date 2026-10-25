#include "harness_start.bash"

# Pointing a pkgconfig LIBRARY at a different template is a change to
# what the rule depends on, but not one make can see by itself: the
# new template is older than the .pc built from the old one, so the
# rule is still "up to date".  Reconfiguring rewrote the build-tree
# copy from the new template and left lib/pkgconfig/x.pc -- and so
# what "make install" puts in place -- built from the one the
# Configfile no longer names.
mkdir -p src

cat >src/old.pc <<'EOF2'
prefix=@@pconfigure_prefix@@
Name: old
Description: x
Version: 1
EOF2

cat >src/new.pc <<'EOF2'
prefix=@@pconfigure_prefix@@
Name: new
Description: x
Version: 1
EOF2

cat >Configfile <<'EOF2'
LANGUAGES   += pkgconfig
LIBRARIES   += pkgconfig/x.pc
SOURCES     += old.pc
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
sleep 1
make $MAKE_ARGS
make $MAKE_ARGS DESTDIR=$tempdir/dest install
grep -q "^Name: old$" lib/pkgconfig/x.pc

sed -i 's@old.pc@new.pc@' Configfile
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
make $MAKE_ARGS DESTDIR=$tempdir/dest install

for pc in obj/pkgconfig/x.pc lib/pkgconfig/x.pc dest/usr/local/lib/pkgconfig/x.pc
do
    cat $pc
    grep -q "^Name: new$" $pc
done
