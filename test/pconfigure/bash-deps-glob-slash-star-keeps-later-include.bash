#include "harness_start.bash"

# The scan that tells make what a script reads is pinclude's C++ side,
# and it strips C comments before it looks for directives.  A shell
# script has no C comments, but it has plenty of globs, and the "/*"
# in "ls dir/*" opens a block comment that nothing ever closes: every
# line after it is blanked, so an include further down is never seen.
# pbashc reads the same file without that and pastes the helper in,
# so the script uses a file make doesn't know about, and editing it
# leaves the compiled script as it was.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

cat >src/tool.bash <<'EOF'
ls "$HOME"/* >/dev/null 2>&1 || true
#include "helper.bash"
echo tool
EOF

cat >src/helper.bash <<'EOF'
echo old
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/tool)" = "old
tool"

grep "^bin/tool:" Makefile | grep -q "src/helper.bash"

sleep 1
cat >src/helper.bash <<'EOF'
echo new
EOF
make $MAKE_ARGS
test "$(./bin/tool)" = "new
tool"
