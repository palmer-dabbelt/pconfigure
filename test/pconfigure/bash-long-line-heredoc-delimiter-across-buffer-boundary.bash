#include "harness_start.bash"

# A "cat <<EOF" at the end of a line more than a thousand characters
# long opens a heredoc that ends at "EOF" like any other.  pbashc used
# to read the line in 1023-byte pieces and look for heredocs in each
# piece on its own, so when the boundary fell inside the delimiter it
# read "<<EO" and then a line "F": the heredoc it was waiting for never
# ended, and the include after the real "EOF" was refused as swallowed.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

# ': "' is three characters and '"; cat ' seven, so 1009 more put
# "<<EO" at the very end of the first 1023 bytes.
pad="$(printf '%1009s' '' | tr ' ' x)"
{
    printf ': "%s"; cat <<EOF\n' "$pad"
    printf '%s\n' hello EOF '#include "helper.bash"' 'echo tool'
} >src/tool.bash

cat >src/helper.bash <<'EOF'
echo helper
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
grep "^bin/tool:" Makefile | grep -q "src/helper.bash"

make $MAKE_ARGS
test "$(./bin/tool)" = "hello
helper
tool"
