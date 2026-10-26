#include "harness_start.bash"

# '-Wdriver,-target,<phase>' says which chisel phase's output is the
# one the library is built from, and a phase name chisel doesn't have
# used to be refused with "Unknown target name" and a dump of the
# context tree.  What's wanted is the line and the phases there are.
mkdir -p src
echo 'object Top' > src/top.scala

cat >Configfile <<'EOF2'
LANGUAGES   += chisel

LIBRARIES   += top.v
COMPILEOPTS += -Wdriver,-target,verilogg
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
grep -q "COMPILEOPTS '-Wdriver,-target,verilogg'" out
grep -q "'verilogg'" out
grep -q "compile, rtl" out
if grep -q "\[LIBRARY\]" out
then
    exit 1
fi
