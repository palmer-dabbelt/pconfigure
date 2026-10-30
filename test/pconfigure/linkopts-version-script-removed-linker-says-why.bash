test "$(uname -s)" == "Darwin" && exit 0
#include "harness_start.bash"

# A file LINKOPTS names is a prerequisite of the link only while it is
# there.  One that has gone missing since pconfigure ran is the
# linker's to complain about, in its own words, rather than make's
# "No rule to make target" -- which names no Configfile line and reads
# as though the build itself were broken.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += c

LIBRARIES += libx.so
LINKOPTS  += -Wl,--version-script=src/x.map
SOURCES   += x.c
EOF

cat >src/x.c <<'EOF'
int foo(void) { return 1; }
EOF

cat >src/x.map <<'EOF'
X1 { global: foo; local: *; };
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS

rm src/x.map
touch src/x.c

if make $MAKE_ARGS >second.out 2>&1
then
    cat second.out
    exit 1
fi
cat second.out
if grep -q "No rule to make target" second.out
then
    exit 1
fi
grep -q "x.map" second.out
