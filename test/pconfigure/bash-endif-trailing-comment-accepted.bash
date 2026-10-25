#include "harness_start.bash"

# Labelling an "#endif" with the name it closes is a habit everyone
# brings over from C, and in a script the label is a shell comment:
# "#endif # WITH_EXTRAS".  pbashc only looks at the start of the line
# and compiles it fine, so pconfigure's scan has to as well rather than
# abort on the comment -- and has to treat it as the "#endif" it is.
#
# The conditional here is one that isn't taken, and the include after
# it is one that is, so the "#endif" closing it is visible in the
# dependencies: had it been skipped, the include after it would still
# be inside the false branch and missing from them.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES   += bash

BINARIES    += tool
COMPILEOPTS += -DWITH_EXTRAS
SOURCES     += tool.bash
EOF

cat >src/tool.bash <<'EOF'
#ifndef WITH_EXTRAS
#include "fallback.bash"
#endif # WITH_EXTRAS
#include "extras.bash"
echo tool
EOF

echo "echo fallback" >src/fallback.bash
echo "echo extras" >src/extras.bash

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/tool)" = "extras
tool"
grep "^bin/tool:" Makefile | grep -q "src/extras.bash"
if grep "^bin/tool:" Makefile | grep -q "src/fallback.bash"
then
    exit 1
fi

exit 0
