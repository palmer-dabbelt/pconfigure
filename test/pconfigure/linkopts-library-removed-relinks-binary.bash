#include "harness_start.bash"

# Dropping a "-l" from a binary's LINKOPTS -- the spelling the manual
# says a DEPLIBS is the same as -- with nothing else changed.  No
# source and no library changed, so the only thing that can make the
# link run again is the link-options hash: the link lands in a new
# directory, so it has to run, and the binary that comes out of it
# stops depending on the library.  A relink that was skipped would
# leave the old binary in place, still asking for libone.so.

export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src

cat >src/one.c <<'EOF'
int one(void) { return 1; }
EOF

cat >src/main.c <<'EOF'
int main(void) { return 0; }
EOF

cat >Configfile <<EOF
AUTORECONFIGURE = true

LANGUAGES += c

LIBRARIES += libone.so
SOURCES   += one.c

BINARIES  += app
LINKOPTS  += -Wl,--no-as-needed
LINKOPTS  += -lone
SOURCES   += main.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
readelf -d bin/app | grep -q "NEEDED.*libone.so"

sleep 2
cat >Configfile <<EOF
AUTORECONFIGURE = true

LANGUAGES += c

LIBRARIES += libone.so
SOURCES   += one.c

BINARIES  += app
LINKOPTS  += -Wl,--no-as-needed
SOURCES   += main.c
EOF

make $MAKE_ARGS > second.out 2>&1
cat second.out
grep -q "^LD	app$" second.out
if readelf -d bin/app | grep -q "NEEDED.*libone.so"
then
    exit 1
fi
