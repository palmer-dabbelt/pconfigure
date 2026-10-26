#include "harness_start.bash"

# A chisel library is a Verilog file copied out of the elaborator, with
# no link step for a LINKOPTS to go to, so one is refused.  The refusal
# used to be a bare "Chisel projects can't have link-time arguments",
# with no line and no word of which option it meant.  The options
# don't carry a line of their own, so it names the LIBRARIES they
# landed on -- the third line, not the LINKOPTS on the fourth -- and
# quotes the option so that it can be found under it.
mkdir -p src
echo 'object Top' > src/top.scala

cat >Configfile <<'EOF2'
LANGUAGES   += chisel

LIBRARIES   += top.v
LINKOPTS    += -lm
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
grep -q "LINKOPTS '-lm'" out
