#include "harness_start.bash"

# A "-Sfile" on a pkgconfig LIBRARY is a sed script the .pc is run
# through, and the script is often written by hand next to the
# template.  It is a prerequisite of both copies of the .pc -- the
# installed one and the build-tree one -- so that editing it rebuilds
# them, and it is named relative to the project, so a subproject's
# script is found from the top.
mkdir -p sub/src

cat >Configfile <<EOF
SUBPROJECTS += sub
EOF

cat >sub/Configfile <<EOF
LANGUAGES   += pkgconfig

LIBRARIES   += pkgconfig/x.pc
COMPILEOPTS += -Sversion.sed
SOURCES     += x.pc
EOF

cat >sub/version.sed <<'EOF'
s/@@VERSION@@/1.0/
EOF

cat >sub/src/x.pc <<'EOF'
prefix=@@pconfigure_prefix@@
Name: x
Description: x
Version: @@VERSION@@
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
grep -q "^Version: 1.0$" sub/lib/pkgconfig/x.pc
grep -q "^Version: 1.0$" sub/obj/pkgconfig/x.pc

sleep 1
cat >sub/version.sed <<'EOF'
s/@@VERSION@@/2.0/
EOF

make $MAKE_ARGS
grep -q "^Version: 2.0$" sub/lib/pkgconfig/x.pc
grep -q "^Version: 2.0$" sub/obj/pkgconfig/x.pc

# A further make with nothing changed has nothing to do for it.
# Judged by the files themselves rather than by what make prints,
# since the short "PKGCFG" label is only printed in quiet mode.
sleep 1
touch settled.stamp
make $MAKE_ARGS
if test -n "$(find sub/lib sub/obj -name x.pc -newer settled.stamp)"
then
    echo "an unchanged sed script rebuilt the .pc" >&2
    exit 1
fi

exit 0
