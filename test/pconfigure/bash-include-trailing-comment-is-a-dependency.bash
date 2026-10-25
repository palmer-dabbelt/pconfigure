#include "harness_start.bash"

# pbashc takes the file name of an include up to its closing quote, so
# a shell comment after it on the same line is fine and the helper is
# pasted in.  The dependency scan has to stop at the same place: a
# script's comments are not blanked out before it is read the way a C
# file's are, so for
#   #include "helper.bash" # the shared helper
# everything after the opening quote is still on the line.  Reading up
# to the last character of it instead names a file called
# 'helper.bash" # the shared helpe', which doesn't exist, and the
# helper the script really reads goes missing from its prerequisites:
# editing it then rebuilds nothing.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

cat >src/tool.bash <<'EOF'
#include "helper.bash" # the shared helper
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
