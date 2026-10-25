#include "harness_start.bash"

# CONFIG_DEPS names something the configuration reads that is not a
# Configfile, and the manual's own example of one is a tool a CONFIG
# asks for its flags.  Such a thing can perfectly well live outside
# the project -- a toolchain directory, a system pkg-config file -- and
# be named by an absolute path.  A relative path is rooted at the
# project whose Configfile the line was in; an absolute one has
# nothing to be rooted at and has to be watched where it is.  Pasted
# onto the project's own directory it names a file that does not
# exist, and the $(wildcard) it goes through makes that silent: the
# thing it was written to watch changes, and nothing reconfigures.

# The reconfigure rule runs whatever the PATH calls "pconfigure", so
# the PATH is what has to be pointed at the one under test.
export PATH="$(dirname "$PTEST_BINARY"):$PATH"

outside="$(pwd)/outside"
mkdir -p "$outside" project/src
cd project

cat >Configfile <<CONFIGFILE
AUTORECONFIGURE  = true
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
CONFIG_DEPS     += $outside
CONFIGFILE

echo 'int main(void) { return 0; }' > src/main.c

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS > first.log 2>&1 || { cat first.log; exit 1; }
grep '^Makefile:' Makefile

# Watched under the name it was written with, and not under that name
# with its leading slash dropped, which is what rooting it at "./" and
# normalizing used to leave.
grep -q "\$(wildcard $outside)" Makefile
if grep -q "\$(wildcard ${outside#/})" Makefile
then
    exit 1
fi

# And it does what the line was for: something appearing in the
# directory outside the project reconfigures.
sleep 1
touch "$outside/new"
make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
grep -q "^PCONFIGURE$" second.log

exit 0
