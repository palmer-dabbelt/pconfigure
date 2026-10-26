#include "harness_start.bash"

# A Configfile's backticks run in that Configfile's project, but a
# line given on the command line has no file behind it: it was typed
# into a shell in the directory pconfigure was started in, and that is
# where whoever typed it expects "cat version" to look.  With --srcpath
# that is the build directory, not the checkout.
mkdir -p checkout/src build
echo 41 >checkout/version
echo 42 >build/version
echo 'int main(void) { return V - 42; }' >checkout/src/v.c
cat >checkout/Configfile <<'EOF'
LANGUAGES   += c
BINARIES    += v
SOURCES     += v.c
EOF

cd build
$PTEST_BINARY $PCONFIGURE_ARGS --srcpath ../checkout 'LANGUAGES += c' 'COMPILEOPTS += -DV=`cat version`'
make $MAKE_ARGS
./bin/v

exit 0
