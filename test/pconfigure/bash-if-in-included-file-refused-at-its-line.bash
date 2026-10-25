#include "harness_start.bash"

# An "#if" is refused in a script, and the one that matters is
# usually not in the file named in SOURCES but in something it pulls
# in.  The error has to name that file and its line rather than the
# top-level script's, or it points somewhere the "#if" isn't.  A
# comment that starts with the word is caught the same way, which is
# why the error also says how to write one that isn't a directive.
mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF2

cat >src/tool.bash <<'EOF2'
#include "helper.bash"
echo tool
EOF2

cat >src/helper.bash <<'EOF2'
echo helper
#if you want more output, add it here
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS >pconfigure.out 2>&1
then
    cat pconfigure.out
    exit 1
fi
cat pconfigure.out

grep -q "^src/helper\.bash:2: '#if you want more output, add it here' can't be used in a script" pconfigure.out
grep -q "or '# if' with a space if this is a comment" pconfigure.out

# Written the way it says, it's a comment to both readers, and the
# script builds.
cat >src/helper.bash <<'EOF2'
echo helper
# if you want more output, add it here
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/tool)" = "$(printf 'helper\ntool')"
