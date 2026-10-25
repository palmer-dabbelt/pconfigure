#include "harness_start.bash"

# A '$' is the end-of-line anchor in a sed expression, and an option
# that is "passed to sed as an argument" has to reach sed with it.
# The recipe is read twice, once by pconfigure's own shell at
# configure time and once by make, and make expands a '$' before any
# shell sees it: left alone, "1$/" became "1" followed by whatever
# make's variable "/" held, so the installed copy and the build-tree
# copy were built from two different expressions.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES   += pkgconfig
LIBRARIES   += pkgconfig/x.pc
COMPILEOPTS += s/^Version: 1$/Version: 2/
SOURCES     += x.pc
EOF

cat >src/x.pc <<'EOF'
prefix=@@pconfigure_prefix@@
Name: x
Description: x
Version: 1
Requires: y >= 1
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
grep -q "^Version: 2$" obj/pkgconfig/x.pc

# Removed so that make has to build it again, rather than trusting the
# one configure left behind.
rm -f obj/pkgconfig/x.pc

make $MAKE_ARGS
for pc in lib/pkgconfig/x.pc obj/pkgconfig/x.pc
do
    cat $pc
    grep -q "^Version: 2$" $pc
    grep -q "^Requires: y >= 1$" $pc
done
