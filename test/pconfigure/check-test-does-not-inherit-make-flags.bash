#include "harness_start.bash"

# A test that runs make of its own -- every test in this tree does --
# must not be handed the flags of the make that is running it.  make
# puts its own flags in the environment of every recipe, so a "make -k
# check" would reach a test as a -k it never asked for, and a "make -B
# check" as an order to rebuild everything inside the test's own
# project too.  A test sees an environment with none of them.

mkdir -p src test/t

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES += t
SOURCES  += t.bash
TESTSRC  += env.bash
EOF

cat >src/t.bash <<'EOF'
echo "Success"
EOF

cat >test/t/env.bash <<'EOF'
echo "MAKEFLAGS=[${MAKEFLAGS-unset}]"
echo "MFLAGS=[${MFLAGS-unset}]"
echo "MAKELEVEL=[${MAKELEVEL-unset}]"
exit 0
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

for flags in "-k" "-B" "-k -e"
do
    rm -rf check
    make $MAKE_ARGS $flags check
    tar -xOf check/t/env.bash ptest__output > env.out
    cat env.out
    grep -q "^MAKEFLAGS=\[unset\]$" env.out
    grep -q "^MFLAGS=\[unset\]$" env.out
    grep -q "^MAKELEVEL=\[unset\]$" env.out
done

exit 0
