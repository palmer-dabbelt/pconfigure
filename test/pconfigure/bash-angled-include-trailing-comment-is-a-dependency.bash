#include "harness_start.bash"

# The angled spelling of an include means the same thing to pbashc as
# the quoted one, and it ends the name at the first '>' just as it ends
# a quoted one at the closing quote.  A shell comment after it on the
# same line must not change which file the dependency scan finds,
# which takes the closing '>' and the comment after it to be the one
# that ends the line.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

cat >src/tool.bash <<'EOF'
#include <helper.bash> # the shared helper, > than the rest
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
