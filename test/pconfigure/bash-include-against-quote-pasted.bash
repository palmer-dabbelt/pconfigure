#include "harness_start.bash"

# '#include"helper.bash"', with nothing between the keyword and the
# quote, is an include to the C preprocessor and to pconfigure's
# scan, which lists helper.bash as a prerequisite: the quote ends the
# keyword as well as a space would.  pbashc only knew the spelling
# with exactly one space, so this one vanished, helper and all.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

printf '%s\n' '#include"helper.bash"' 'echo tool' >src/tool.bash

cat >src/helper.bash <<'EOF'
echo helper
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
grep "^bin/tool:" Makefile | grep -q "src/helper.bash"

make $MAKE_ARGS
cat bin/tool
test "$(./bin/tool)" = "helper
tool"
