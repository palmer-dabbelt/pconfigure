test "$(uname -s)" == "Darwin" && exit 0
#include "harness_start.bash"

# A version script decides which symbols a shared library exports, and
# it reaches the linker through LINKOPTS.  It is as much an input to
# the link as any object, but the link rule only waited on the objects
# and on files this build makes itself, so an edit to the script left
# the library as it was: "make" had nothing to do and bar() was still
# exported.
#
# AUTORECONFIGURE = true, where the objects reach the link line through
# what make found as prerequisites rather than a list pconfigure wrote
# down, so the script turning up among them must not change that.

mkdir -p src

cat >Configfile <<'EOF'
AUTORECONFIGURE = true

LANGUAGES += c

LIBRARIES += libx.so
LINKOPTS  += -Wl,--version-script=src/x.map
SOURCES   += x.c
EOF

cat >src/x.c <<'EOF'
int foo(void) { return 1; }
int bar(void) { return 2; }
EOF

cat >src/x.map <<'EOF'
X1 { global: foo; bar; local: *; };
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
nm -D --defined-only lib/libx.so | grep -qw bar

# Far enough in the past that the edit below is newer whatever the
# filesystem's timestamp resolution.
find . -type f -exec touch -t 200001010000 {} +

cat >src/x.map <<'EOF'
X1 { global: foo; local: *; };
EOF

make $MAKE_ARGS
nm -D --defined-only lib/libx.so | grep -qw foo
if nm -D --defined-only lib/libx.so | grep -qw bar
then
    exit 1
fi
