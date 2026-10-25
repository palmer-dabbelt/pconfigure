#include "harness_start.bash"

# A script in one subdirectory of the source tree includes a file from
# a sibling subdirectory through "../", the way a quoted include is
# resolved from the including file's own directory.  pbashc pastes it,
# and the dependency scan has to resolve it the same way: the rule
# names the included file by where it really is, so editing it
# rebuilds the script.  The sibling directory's name has a dot in it,
# which is nothing to either of them.
mkdir -p src/sub src/lib.d

cat >src/sub/x.bash <<'EOF'
#include "../lib.d/l.bash"
hello
EOF
echo 'hello() { echo one; }' > src/lib.d/l.bash

cat >Configfile <<EOF
LANGUAGES += bash
BINARIES  += x
SOURCES   += sub/x.bash
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/x)" = one
grep -q "^bin/x:.* src/lib.d/l.bash" Makefile

sleep 1
echo 'hello() { echo two; }' > src/lib.d/l.bash
make $MAKE_ARGS
test "$(./bin/x)" = two
