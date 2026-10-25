#include "harness_start.bash"

# The "#endif" half of the same mistake: a comment that begins with the
# letters of "#endif" -- "#endifs" -- was taken for one, closing the
# "#ifdef" it was written inside.  The rest of a branch that wasn't
# taken leaked into the script, and the real "#endif" that followed
# then had nothing left to close, which pbashc answered by aborting.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

cat >src/tool.bash <<'EOF'
#ifdef FANCY
#endifs come in pairs with the ifdefs above them
#include "fancy.bash"
#endif
echo tool
EOF

cat >src/fancy.bash <<'EOF'
echo fancy
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
cat bin/tool
test "$(./bin/tool)" = "tool"
