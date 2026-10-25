#include "harness_start.bash"

# A shell comment that happens to end in a backslash -- a Windows path
# is the usual way to write one -- ends at its newline like any other.
# The dependency scan splices it onto the next line the way the C
# preprocessor would, and when that next line is an include the
# include becomes part of a comment and is never listed.  pbashc
# pastes it in all the same.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

cat >src/tool.bash <<'EOF'
# on the other machine this lives in C:\tools\
#include "helper.bash"
echo tool
EOF

cat >src/helper.bash <<'EOF'
echo helper
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/tool)" = "helper
tool"

grep "^bin/tool:" Makefile | grep -q "src/helper.bash"
