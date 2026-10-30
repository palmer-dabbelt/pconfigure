test "$(uname -s)" == "Darwin" && exit 0
#include "harness_start.bash"

# "-Wl,-Map=FILE" names a file the link writes, not one it reads.  It
# is there after the first link, written a moment after the program
# was, so taking it for an input would make every build relink a
# program that was already up to date.  Both spellings, stuck on with
# an '=' and as the next word.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += c

BINARIES  += app
LINKOPTS  += -Wl,-Map=src/app.map
SOURCES   += main.c

BINARIES  += app2
LINKOPTS  += -Wl,-Map,src/app2.map
SOURCES   += main.c
EOF

cat >src/main.c <<'EOF'
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test -f src/app.map
test -f src/app2.map

# Configured again with the maps there, which is when pconfigure
# could mistake them for inputs.
$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
make $MAKE_ARGS -q
