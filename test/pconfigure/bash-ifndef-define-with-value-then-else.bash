#include "harness_start.bash"

# "#ifndef" with an "#else", where the name is defined with a value:
# the "#else" half is the one pasted, the other half's include is
# neither pasted nor a prerequisite, and the value is substituted
# into the text of the script.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES   += bash

BINARIES    += tool
COMPILEOPTS += -DFLAVOR=vanilla
SOURCES     += tool.bash
EOF

cat >src/tool.bash <<'EOF'
#ifndef FLAVOR
#include "plain.bash"
#else
#include "fancy.bash"
#endif
echo tool
EOF

cat >src/plain.bash <<'EOF'
echo plain
EOF

cat >src/fancy.bash <<'EOF'
echo fancy FLAVOR
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/tool)" = "fancy vanilla
tool"
grep "^bin/tool:" Makefile | grep -q "src/fancy.bash"
if grep "^bin/tool:" Makefile | grep -q "src/plain.bash"
then
    exit 1
fi
