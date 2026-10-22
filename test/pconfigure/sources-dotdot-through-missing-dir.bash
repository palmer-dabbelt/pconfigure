#include "harness_start.bash"

# "gone/../main.c" is decided to be inside the project by normalizing
# it, which is text arithmetic: the ".." takes the "gone" back off
# whether or not there is a "gone".  The compile line used the text as
# written, though, and the kernel resolves "src/gone/../main.c" one
# component at a time -- there being no src/gone, there is no
# main.c behind it either.  So a line pconfigure had just judged to be
# fine was a compile that couldn't find its source.  The judgement and
# the use have to be of the same path.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

cat >Configfile <<EOF
LANGUAGES += c

BINARIES  += main
SOURCES   += gone/../main.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
./bin/main
