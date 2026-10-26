#include "harness_start.bash"

# '-W<phase>,<arg>' sends one argument to one chisel phase.  The phase
# name used to be cut out of the option one character too long, so
# '-Wrtl,-top,Board' looked up a phase called "rtl," and every option
# of this shape, spelled right or not, killed pconfigure with an
# uncaught exception.  Here the RTL phase is told its top module is
# Board, which is what the elaborator is run on and what the Verilog
# it writes is called.  The phase name is matched without regard to
# case, so it is written the way the manual's examples would.
mkdir -p src
echo 'object Board' > src/top.scala

cat >Configfile <<'EOF2'
LANGUAGES   += chisel

LIBRARIES   += top.v
COMPILEOPTS += -Wrtl,-top,Board
SOURCES     += top.scala
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
grep -q "scala .* Board --targetDir" Makefile
grep -q "/Board\.v" Makefile
