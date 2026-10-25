#include "harness_start.bash"

# A script that writes a Makefile writes continuation lines, and in a
# quoted heredoc the backslash at the end of one is just a character:
# the next line is still the delimiter and the heredoc ends there.
# pbashc reads it that way.  The dependency scan splices any line
# ending in a backslash onto the next one first, the way the C
# preprocessor does, so the delimiter disappears into the body line
# above it, the heredoc never ends, and the include after it is never
# counted as something the script reads.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

cat >src/tool.bash <<'EOF'
cat >gen.mk <<'MK'
SRCS = a.c \
MK
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
