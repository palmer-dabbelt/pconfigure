#include "harness_start.bash"

# An "#include" is a directive only at the start of a line.  Written
# in the middle of a long string it is text, and pconfigure's scan,
# which reads whole lines, leaves it alone.  pbashc used to read 1023
# bytes at a time and treat each piece as a line, so when the text
# landed right at a piece boundary it pasted helper.bash into the
# middle of the string and dropped the rest of the line, quote and all.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

cat >src/helper.bash <<'EOF'
echo helper
EOF

# "echo '" is six characters, and 1017 more end the first piece.
pad="$(printf '%1017s' '' | tr ' ' x)"
printf "echo '%s#include \"helper.bash\" is text'\n" "$pad" >src/tool.bash

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/tool)" = "${pad}#include \"helper.bash\" is text"
