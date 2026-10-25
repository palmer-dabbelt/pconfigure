#include "harness_start.bash"

# The other side of keeping a "-S" sed script off the list the
# template is taken from: with a SOURCES as well, the template is what
# gets installed and the script is what gets run over it, whichever
# order the two lines come in.  The script is written before the
# SOURCES here, which is the order most likely to put it first on a
# shared list.
mkdir -p src

cat >Configfile <<EOF
LANGUAGES   += pkgconfig
LIBRARIES   += pkgconfig/x.pc
COMPILEOPTS += -Sversion.sed
SOURCES     += x.pc
EOF

cat >version.sed <<'EOF'
s/@@VERSION@@/1.0/
EOF

cat >src/x.pc <<'EOF'
prefix=@@pconfigure_prefix@@
Name: x
Description: x
Version: @@VERSION@@
Libs: -L${prefix}/lib -lx
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

cat lib/pkgconfig/x.pc
grep -q "^Version: 1.0$" lib/pkgconfig/x.pc
grep -q "^Libs: " lib/pkgconfig/x.pc
grep -q "^Version: 1.0$" obj/pkgconfig/x.pc
