#include "harness_start.bash"

# End to end: a Configfile asks ppkg-config for a package that lives
# in a subdirectory of /usr/lib, which is how Debian lays out every
# package that keeps its libraries apart.  The search path should
# reach the link line as the package wrote it; instead the link line
# gets the bare word "/x86_64-linux-gnu/thing/lib", which the
# compiler reads as an input file that doesn't exist.
ppkg="$(dirname "$PTEST_BINARY")/ppkg-config"
test -x "$ppkg"

# A pkg-config that answers with exactly what the test wants, so that
# what ppkg-config does to the answer is all that is being looked at.
mkdir fakebin
cat >fakebin/pkg-config <<EOF
#!/bin/bash
echo "\$FAKE_PKG_CONFIG_OUTPUT"
EOF
chmod +x fakebin/pkg-config
export PATH="$(pwd)/fakebin:$PATH"
export FAKE_PKG_CONFIG_OUTPUT="-L/usr/lib/x86_64-linux-gnu/thing/lib"

mkdir -p src
cat >Configfile <<EOF
LANGUAGES   += c

BINARIES    += test
LINKOPTS    += \`ppkg-config thing --libs\`
SOURCES     += test.c
EOF

cat >src/test.c <<EOF
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

grep -q -- "-L/usr/lib/x86_64-linux-gnu/thing/lib" Makefile
if grep -q -- " /x86_64-linux-gnu/thing/lib" Makefile
then
    exit 1
fi

make $MAKE_ARGS

exit 0
