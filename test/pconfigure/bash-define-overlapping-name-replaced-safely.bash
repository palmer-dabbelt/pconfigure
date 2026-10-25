#include "harness_start.bash"

# "-DNAME=value" replaces NAME wherever it appears in what pbashc
# writes.  The replacement used to size its output by counting matches
# at every offset, overlapping ones included, and then replace only the
# ones that don't overlap -- so for a name that can overlap itself the
# count was too high, and with a value shorter than the name the buffer
# came out too small.  A long enough run of the name wrote past the end
# of the heap block, and glibc killed pbashc with "malloc(): corrupted
# top size".
#
# The short line pins down which matches are meant: they are taken
# left to right and don't overlap, so "XXX" is one "XX" and a left
# over "X".
mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES   += bash

BINARIES    += tool
COMPILEOPTS += -DXX=y
SOURCES     += tool.bash
EOF2

# A line of 500 "XX" is 1000 bytes of it, far more than the seven the
# old count left room for, and still short enough that it reaches
# pbashc as one line rather than in pieces.
pairs="$(printf 'XX%.0s' $(seq 1 500))"
echo "echo $pairs" > src/tool.bash
echo "echo XXX" >> src/tool.bash

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
expected="$(printf 'y%.0s' $(seq 1 500))"
test "$(./bin/tool | sed -n 1p)" = "$expected"
test "$(./bin/tool | sed -n 2p)" = "yX"
