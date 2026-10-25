#include "harness_start.bash"

# The manual says of --debug that it "is about pconfigure rather than
# about the build ... the Makefile it writes is the same one either
# way".  It wasn't: the options a run was given are recorded as the
# default PCONFIGURE_ARGS, and --debug went in with the rest, so the
# Makefile differed by that line -- and every reconfigure after it,
# including the ones AUTORECONFIGURE sets off over nothing more than a
# comment in a Configfile, printed pconfigure's debugging dump into
# the middle of somebody's build.

# The rule runs whatever the PATH says "pconfigure" is, so the PATH is
# what has to be pointed at the one being tested.
export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src
echo 'int main(void) { return 0; }' > src/hello.c
cat >Configfile <<'EOF2'
LANGUAGES += c
BINARIES  += hello
SOURCES   += hello.c
EOF2

$PTEST_BINARY
cp Makefile plain.mk

# The dump is still printed for the run that asked for it.
$PTEST_BINARY --debug > debug.out 2>&1
cat debug.out
grep -q "Building Context: hello" debug.out

diff -u plain.mk Makefile

# And not for the run make starts on its own later.
make $MAKE_ARGS reconfigure > reconfigure.out 2>&1
cat reconfigure.out
grep -q "^PCONFIGURE$" reconfigure.out
if grep -q "Building Context" reconfigure.out
then
    exit 1
fi

# Only the option is left out.  The same word given as the argument to
# another option is a name somebody chose -- here, of the extra
# Configfile "--config" pulls in -- and a reconfigure without it would
# be a different configure from the one that was asked for.
mkdir -p Configfiles
echo 'LANGUAGES += c' > Configfiles/--debug
echo 'BINARIES += extra' >> Configfiles/--debug
echo 'SOURCES  += hello.c' >> Configfiles/--debug
$PTEST_BINARY --config --debug
grep -q "^PCONFIGURE_ARGS ?= --config --debug$" Makefile
make $MAKE_ARGS reconfigure
grep -q "^bin/extra:" Makefile

exit 0
