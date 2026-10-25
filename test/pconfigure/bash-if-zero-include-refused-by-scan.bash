#include "harness_start.bash"

# "#if" used to mean two different things to the two readers of a
# script.  The dependency scan evaluated it, so "#if 0" hid the include
# under it and the helper was not a prerequisite.  pbashc only
# pretended to: every "#if" was taken as true, so the helper was pasted
# in anyway, and make never heard about a file the script was made of.
# Both now refuse an "#if" in a script, and this is the half of that
# which pconfigure says, pointing at the line and naming what to write.
mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF2

cat >src/tool.bash <<'EOF2'
#if 0
#include "helper.bash"
#endif
echo tool
EOF2

cat >src/helper.bash <<'EOF2'
echo helper
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS >pconfigure.out 2>&1
then
    cat pconfigure.out
    exit 1
fi
cat pconfigure.out

grep -q "^src/tool\.bash:1: '#if 0' can't be used in a script" pconfigure.out
grep -q "write '#ifdef NAME'" pconfigure.out

# What it says to write instead does what "#if 0" was after: a name
# nothing defines leaves the helper out of the script and off its
# prerequisites both.
cat >src/tool.bash <<'EOF2'
#ifdef NEVER_DEFINED
#include "helper.bash"
#endif
echo tool
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
cat bin/tool

if grep "^bin/tool:" Makefile | grep -q "src/helper\.bash"
then
    exit 1
fi
if grep -q "^echo helper$" bin/tool
then
    exit 1
fi
test "$(./bin/tool)" = "tool"
