#include "harness_start.bash"

# pbashc used to take every "#if" as true, so "#if 0" around an
# include pasted the include in regardless.  It now refuses an "#if"
# outright, the same as pconfigure's scan of the script does.  The
# scan gets there first when both see the line, so to reach pbashc's
# half the "#if" is written in after the project has been configured,
# which is what an edit between two makes looks like when nothing
# reconfigures.
mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF2

cat >src/tool.bash <<'EOF2'
echo tool
EOF2

cat >src/helper.bash <<'EOF2'
echo helper
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS

cat >src/tool.bash <<'EOF2'
echo tool
#if 0
#include "helper.bash"
#endif
EOF2

if make $MAKE_ARGS >make.out 2>&1
then
    cat make.out
    cat bin/tool
    exit 1
fi
cat make.out

grep -q "^src/tool\.bash:2: '#if 0' can't be used in a script" make.out
grep -q "write '#ifdef NAME'" make.out

# And nothing was put in place, so the next make tries again rather
# than finding a program it takes for finished.
test ! -e bin/tool
