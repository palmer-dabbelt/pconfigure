#include "harness_start.bash"

# Two helpers that both include the same common file get one copy of
# it in the compiled script, not two: pbashc keeps a list of what it
# has already pasted.  The common file is still a prerequisite.  It is
# listed once per helper that reaches it, which make doesn't mind, so
# the count isn't pinned here -- only that it is there.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

cat >src/tool.bash <<'EOF'
#include "a.bash"
#include "b.bash"
echo tool
EOF

cat >src/a.bash <<'EOF'
#include "common.bash"
echo a
EOF

cat >src/b.bash <<'EOF'
#include "common.bash"
echo b
EOF

cat >src/common.bash <<'EOF'
echo common
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/tool)" = "common
a
b
tool"
grep "^bin/tool:" Makefile | grep -q "src/common.bash"

# The prerequisite is only worth anything if an edit to the common
# file rebuilds the script and the new text is what gets pasted.
sleep 1
cat >src/common.bash <<'EOF'
echo changed
EOF
make $MAKE_ARGS
test "$(./bin/tool)" = "changed
a
b
tool"
