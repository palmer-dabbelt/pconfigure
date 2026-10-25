#include "harness_start.bash"

# A "<<<" here-string and a "<<" shift written against a number are
# not heredocs, and neither waits for a body.  An include on the very
# next line is still an include: pasted by pbashc and listed as a
# prerequisite.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

cat >src/tool.bash <<'EOF'
read -r word <<< "here"
echo "$word $((1<<4))"
#include "helper.bash"
echo tool
EOF

cat >src/helper.bash <<'EOF'
echo helper
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/tool)" = "here 16
helper
tool"
grep "^bin/tool:" Makefile | grep -q "src/helper.bash"
