#include "harness_start.bash"

# The same line as config-deps-absolute-path-kept-absolute, but in a
# subproject's Configfile.  A relative CONFIG_DEPS there is rooted at
# the subproject, which is right; an absolute one is not relative to
# anything, so it must come out of that rooting unchanged rather than
# as a path under the subproject's directory.

# The reconfigure rule runs whatever the PATH calls "pconfigure", so
# the PATH is what has to be pointed at the one under test.
export PATH="$(dirname "$PTEST_BINARY"):$PATH"

outside="$(pwd)/outside"
mkdir -p "$outside" project/src project/sub/src
cd project

cat >Configfile <<'CONFIGFILE'
AUTORECONFIGURE  = true
SUBPROJECTS     += sub
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
CONFIGFILE

cat >sub/Configfile <<CONFIGFILE
LANGUAGES       += c
BINARIES        += subbin
SOURCES         += sub.c
CONFIG_DEPS     += $outside
CONFIGFILE

echo 'int main(void) { return 0; }' > src/main.c
echo 'int main(void) { return 0; }' > sub/src/sub.c

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS > first.log 2>&1 || { cat first.log; exit 1; }
grep '^Makefile:' Makefile

grep -q "\$(wildcard $outside)" Makefile
if grep -q "\$(wildcard sub$outside)" Makefile
then
    exit 1
fi

sleep 1
touch "$outside/new"
make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
grep -q "^PCONFIGURE$" second.log

exit 0
