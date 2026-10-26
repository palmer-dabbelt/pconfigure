#include "harness_start.bash"

# chisel turns Scala into a Verilog file, which it puts in the library
# directory, so the only target it can build is a LIBRARIES.  A
# BINARIES built from Scala used to be refused with an internal
# "Unimplemented context type: BINARY" and a dump of the context tree,
# which says neither which line was at fault nor what to write instead.
# The BINARIES is the third line, so a message that names the first
# line or the SOURCES can't pass by accident.
mkdir -p src
echo 'object Top' > src/top.scala

cat >Configfile <<'EOF2'
LANGUAGES += chisel

BINARIES  += top
SOURCES   += top.scala
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    cat out
    exit 1
fi
cat out
test ! -e Makefile
grep -q "Configfile:3" out
grep -q "LIBRARIES += top.v" out
if grep -q "Unimplemented context type" out
then
    exit 1
fi
