#include "harness_start.bash"

# An "#else" flips the branch it belongs to, not whether anything
# around that branch is taken.  Inside an "#ifdef" that is off, the
# "#else" of an inner "#ifdef" is as dead as the inner "#ifdef" itself:
# flipping it on would paste and list a file the outer test said to
# leave out.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

cat >src/tool.bash <<'EOF'
#ifdef WITH_EXTRAS
#ifdef EXTRAS_ARE_BUILTIN
#else
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
