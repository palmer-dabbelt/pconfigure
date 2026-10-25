#include "harness_start.bash"

# A sed expression written as a COMPILEOPTS on a pkgconfig LIBRARY is
# part of how the .pc is built, but it lives in the recipe rather than
# in any file the rule depends on -- and make never reruns a rule
# because its recipe changed.  So editing the expression and
# reconfiguring rewrote the build-tree copy pconfigure makes for
# itself, while lib/pkgconfig/x.pc and the installed copy kept the old
# answer: one tree, two different versions of the same package, and
# "make install" saying there was nothing to do.
mkdir -p src

cat >src/x.pc <<'EOF2'
prefix=@@pconfigure_prefix@@
Name: x
Description: x
Version: @@VERSION@@
EOF2

cat >Configfile <<'EOF2'
LANGUAGES   += pkgconfig
LIBRARIES   += pkgconfig/x.pc
COMPILEOPTS += s/@@VERSION@@/1.0/
SOURCES     += x.pc
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
make $MAKE_ARGS DESTDIR=$tempdir/dest install
grep -q "^Version: 1.0$" lib/pkgconfig/x.pc
grep -q "^Version: 1.0$" dest/usr/local/lib/pkgconfig/x.pc

sleep 1
sed -i 's@/1.0/@/2.0/@' Configfile
cat Configfile

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
make $MAKE_ARGS DESTDIR=$tempdir/dest install

for pc in obj/pkgconfig/x.pc lib/pkgconfig/x.pc dest/usr/local/lib/pkgconfig/x.pc
do
    cat $pc
    grep -q "^Version: 2.0$" $pc
done
