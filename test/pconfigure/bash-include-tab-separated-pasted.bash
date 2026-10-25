#include "harness_start.bash"

# The same as with two spaces, but with a tab between "#include" and
# the name, which is how an editor that indents with tabs writes it.
# The scan skips any blanks after the keyword, so pbashc has to as
# well or the helper make depends on never makes it into the script.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

printf '#include\t"helper.bash"\necho tool\n' >src/tool.bash

cat >src/helper.bash <<'EOF'
echo helper
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
grep "^bin/tool:" Makefile | grep -q "src/helper.bash"

make $MAKE_ARGS
cat bin/tool
test "$(./bin/tool)" = "helper
tool"
