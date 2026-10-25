#include "harness_start.bash"

# An angled include means the same as a quoted one in a script, and
# it is spelled with whatever blanks the quoted one is: pbashc turned
# only "#include <" into a quoted include, so '#include  <helper.bash>'
# was dropped without anything pasted in its place.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

printf '%s\n' '#include  <helper.bash>' 'echo tool' >src/tool.bash

cat >src/helper.bash <<'EOF'
echo helper
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
grep "^bin/tool:" Makefile | grep -q "src/helper.bash"

make $MAKE_ARGS
cat bin/tool
test "$(./bin/tool)" = "helper
tool"
