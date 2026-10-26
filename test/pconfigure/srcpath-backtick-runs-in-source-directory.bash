#include "harness_start.bash"

# A Configfile's backticks belong to the tree the Configfile is in.
# Configured out of tree with --srcpath they ran in the build
# directory instead, so a "cat version" that works in the checkout
# can't find the file from a build directory beside it.
mkdir -p checkout/src build
echo 42 > checkout/version
echo 'int main(void) { return V - 42; }' > checkout/src/v.c
cat >checkout/Configfile <<'EOF2'
LANGUAGES   += c
BINARIES    += v
COMPILEOPTS += -DV=`cat version`
SOURCES     += v.c
EOF2

cd build
$PTEST_BINARY $PCONFIGURE_ARGS --srcpath ../checkout
make $MAKE_ARGS
./bin/v

exit 0
