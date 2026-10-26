#include "harness_start.bash"

# chisel reads its COMPILEOPTS as '-W<phase>,<arg>' or
# '-Wdriver,<arg>' and nothing else.  Anything else used to be refused
# as an "unknown Chisel argument" followed by a dump of the context
# tree.  The refusal names the LIBRARIES the option landed on (the
# options don't carry a line of their own), quotes the option, and
# says which shapes chisel does read.
mkdir -p src
echo 'object Top' > src/top.scala

cat >Configfile <<'EOF2'
LANGUAGES   += chisel

LIBRARIES   += top.v
COMPILEOPTS += -O2
SOURCES     += top.scala
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    cat out
    exit 1
fi
cat out
test ! -e Makefile
grep -q "Configfile:3" out
grep -q "COMPILEOPTS '-O2'" out
grep -q -- "-W<phase>,<arg>" out
if grep -q "\[LIBRARY\]" out
then
    exit 1
fi
