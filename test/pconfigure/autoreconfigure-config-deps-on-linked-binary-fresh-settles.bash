#include "harness_start.bash"

# CONFIG_DEPS on a program a subproject of the same build links, from a
# tree where it hasn't been linked yet.
#
# The case is a tree with a simulator in one subproject and a Configfile
# elsewhere that bakes the simulator's path in, or stamps what it found,
# and so watches the binary.  On a fresh tree -- or one whose object
# directory somebody threw away -- the binary is missing, and the
# $(wildcard) a watched name went through expanded to nothing: make
# never learned the configuration was waiting on it.  The first make
# configured without it, linked it during the goals, and exited 0; the
# second make found it newer than the Makefile, configured again, and
# rebuilt whatever the answer changed.  A build that needs two makes to
# say what one should is a build nobody can tell is finished.
#
# The name is written bare once make has read every dependency fragment
# it includes, so it builds the program before deciding whether to
# reconfigure, the way it does a vendored tree's tool.  Not before then:
# the program's objects are prerequisites those fragments add, and a
# link out of fragments make hasn't read is a link out of nothing.

# The rule runs whatever the PATH calls "pconfigure", the same as
# "make reconfigure" does, so the PATH is what has to be pointed at
# the one under test.
export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p sim/src Configfiles

cat >Configfile <<'CONFIGFILE'
AUTORECONFIGURE = true
SUBPROJECTS    += sim
CONFIG         += probe
CONFIGFILE

# The probe watches the program and says whether it found it, which is
# what the assertions read back out of the Makefile.
cat >Configfiles/probe <<'PROBE'
#!/bin/bash
echo "CONFIG_DEPS += sim/bin/sim"
if test -e sim/bin/sim
then
    echo "PHONY += sim-found"
else
    echo "PHONY += sim-missing"
fi
PROBE
chmod +x Configfiles/probe

cat >sim/Configfile <<'CONFIGFILE'
LANGUAGES += c++
BINARIES  += sim
SOURCES   += main.c++
CONFIGFILE

cat >sim/src/main.c++ <<'SOURCE'
#include "sim.h++"
int main(void) { return answer() == 42 ? 0 : 1; }
SOURCE

cat >sim/src/sim.h++ <<'SOURCE'
int answer(void);
SOURCE

cat >sim/src/sim.c++ <<'SOURCE'
#include "sim.h++"
int answer(void) { return 42; }
SOURCE

$PTEST_BINARY $PCONFIGURE_ARGS
grep -q 'sim-missing' Makefile

# One make: the program is linked before the probe is asked again, so
# the Makefile the goals run under is one that found it.
make $MAKE_ARGS > first.log 2>&1 || { cat first.log; exit 1; }
cat first.log
test -x sim/bin/sim
sim/bin/sim
grep -q 'sim-found' Makefile
if grep -q 'sim-missing' Makefile
then
    exit 1
fi

# And a second make settles.
make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
if grep -q "^PCONFIGURE$" second.log
then
    exit 1
fi

# The same again from an object directory thrown away, with the program
# gone along with it.
rm -rf sim/obj sim/bin
make $MAKE_ARGS > third.log 2>&1 || { cat third.log; exit 1; }
cat third.log
sim/bin/sim
grep -q 'sim-found' Makefile
make $MAKE_ARGS > fourth.log 2>&1 || { cat fourth.log; exit 1; }
cat fourth.log
if grep -q "^PCONFIGURE$" fourth.log
then
    exit 1
fi

# A "make clean" is not a reason to link it: with the program gone and
# the fragments still there, nothing is built on the way to cleaning.
rm -f sim/bin/sim
make $MAKE_ARGS clean > clean.log 2>&1 || { cat clean.log; exit 1; }
cat clean.log
if grep -q "LD" clean.log
then
    exit 1
fi
