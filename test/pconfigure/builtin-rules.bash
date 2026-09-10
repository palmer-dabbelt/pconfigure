#include "harness_start.bash"

# GNU make ships a "%: %.sh" rule, and it fires on any prerequisite
# that has no rule of its own: the file is replaced by the .sh sitting
# next to it.  Buildroot ships exactly that pair -- arch/Config.in
# beside an arch/Config.in.sh which is the kconfig for SuperH rather
# than a shell script -- so a generated Makefile that leaves the
# built-ins in place quietly overwrites the first with the second, and
# what is seen is a build dying much later on an empty ARCH.
#
# A generated Makefile says what builds what.  A prerequisite it wrote
# no rule for is an error worth printing, never a guess worth making.

mkdir -p src

cat >Configfile <<CONFIGFILE
LANGUAGES += c
BINARIES  += test
SOURCES   += test.c
CONFIGFILE

cat >src/test.c <<SOURCE
int main(void) { return 0; }
SOURCE

$PTEST_BINARY $PCONFIGURE_ARGS

cat Makefile

# Only the impostor exists.  Nothing in this tree says how to build a
# "victim", so the only thing that could produce one is a built-in
# rule guessing that the .sh beside it is how -- which makes the file
# appearing at all the whole of the test, with no timestamps in it.
echo "the impostor" >victim.sh

# Asked for through the generated Makefile, because that is where the
# cancellation has to be for the rest of the build to inherit it.
cat >probe.mk <<PROBE
include Makefile
.PHONY: probe
probe: victim
PROBE

if make -f probe.mk probe
then
    echo "make built 'victim' out of the 'victim.sh' beside it" >&2
    exit 1
fi

if test -e victim
then
    echo "'victim' was written by a built-in rule" >&2
    exit 1
fi

# And the build the project actually asked for still works, which is
# the other half of cancelling rules: nothing here was relying on one.
make
./bin/test
