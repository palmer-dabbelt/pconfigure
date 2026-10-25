#include "harness_start.bash"

# A conditional inside a branch that isn't taken is not taken either,
# whatever its own test says.  An "#ifndef" of a name nobody defined,
# written inside an "#ifdef" of another name nobody defined, is true on
# its own -- but the "#ifdef" around it already switched everything off,
# so neither pbashc's paste nor the scan that lists a script's
# dependencies may let its "#include" back in.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

cat >src/tool.bash <<'EOF'
#ifdef WITH_EXTRAS
#ifndef EXTRAS_ARE_BUILTIN
#include "extras.bash"
#endif
#endif
echo tool
EOF

cat >src/extras.bash <<'EOF'
echo extras
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
cat bin/tool

test "$(./bin/tool)" = "tool"
if grep "^bin/tool:" Makefile | grep -q "src/extras.bash"
then
    exit 1
fi
