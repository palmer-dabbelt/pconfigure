#include "harness_start.bash"

# Two targets are only refused for nesting when one's output is a
# directory the other one's lands in, not whenever one name starts with
# the other: "tools", "tools-run/run" and "tools.d/run" are three
# separate paths in bin/, and "-" and "." sort on either side of "/",
# which is the place a careless prefix check would get it wrong.
mkdir -p src
echo 'int main(void) { return 0; }' > src/a.c
echo 'int main(void) { return 0; }' > src/b.c
echo 'int main(void) { return 0; }' > src/c.c

cat >Configfile <<EOF
LANGUAGES += c

BINARIES  += tools-run/run
SOURCES   += a.c

BINARIES  += tools
SOURCES   += b.c

BINARIES  += tools.d/run
SOURCES   += c.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test -f bin/tools
test -f bin/tools-run/run
test -f bin/tools.d/run
