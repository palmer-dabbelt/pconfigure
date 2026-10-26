#include "harness_start.bash"

# A chisel COMPILEOPTS of the shape '-W<phase>,<arg>' goes to one
# phase, and the phase is looked up by name.  A name that isn't a
# phase made the lookup throw a C++ string nothing caught, so
# pconfigure died with "terminate called after throwing an instance
# of 'std::...basic_string'" and no word about chisel, the option or
# the line.  It is a refusal like any other: the LIBRARIES line, the
# option, and the phases there are.
mkdir -p src
echo 'object Top' > src/top.scala

cat >Configfile <<'EOF2'
LANGUAGES   += chisel

LIBRARIES   += top.v
COMPILEOPTS += -Wbogus,--fast
SOURCES     += top.scala
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    cat out
    exit 1
fi
cat out
test ! -e Makefile
if grep -q "terminate called" out
then
    exit 1
fi
grep -q "Configfile:3" out
grep -q "COMPILEOPTS '-Wbogus,--fast'" out
grep -q "'bogus'" out
grep -q "compile, rtl" out
