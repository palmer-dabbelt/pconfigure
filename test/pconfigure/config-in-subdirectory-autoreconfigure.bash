#include "harness_start.bash"

# A CONFIG name may have a directory in it, read from under
# Configfiles/ like any other, and under AUTORECONFIGURE that nested
# file is watched the same as a flat one: a target added to it is
# built by the next plain "make" with no pconfigure run in between.
mkdir -p src Configfiles/sub.d
echo 'int main(void) { return 0; }' > src/main.c
echo 'int main(void) { return 0; }' > src/two.c

cat >Configfiles/sub.d/conf <<EOF
BINARIES  += main
SOURCES   += main.c
EOF

cat >Configfile <<EOF
AUTORECONFIGURE = true
LANGUAGES += c
CONFIG    += sub.d/conf
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
./bin/main
test ! -e bin/two

sleep 1
cat >>Configfiles/sub.d/conf <<EOF
BINARIES  += two
SOURCES   += two.c
EOF

make $MAKE_ARGS
./bin/two
