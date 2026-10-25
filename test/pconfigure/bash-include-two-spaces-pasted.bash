#include "harness_start.bash"

# An "#include" with two spaces before its name is still plainly an
# include, and pconfigure's scan reads it as one: helper.bash goes on
# the script's prerequisites.  pbashc dropped the line from its output
# as a directive but only pasted a file in when exactly one space came
# before the quote, so the script was built with its helper silently
# missing and pbashc exited zero.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

printf '%s\n' '#include  "helper.bash"' 'echo tool' >src/tool.bash

cat >src/helper.bash <<'EOF'
echo helper
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
grep "^bin/tool:" Makefile | grep -q "src/helper.bash"

make $MAKE_ARGS
cat bin/tool
test "$(./bin/tool)" = "helper
tool"
