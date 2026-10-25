#include "harness_start.bash"

# "helper.bash" and "./helper.bash" name the same file beside the
# script.  Included both ways -- once directly and once from a second
# helper that spells it with the "./" -- it is still one file, which
# the manual says pbashc pastes in at most once.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

cat >src/tool.bash <<'EOF'
#include "helper.bash"
#include "other.bash"
echo tool
EOF

cat >src/other.bash <<'EOF'
#include "./helper.bash"
echo other
EOF

cat >src/helper.bash <<'EOF'
echo helper
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/tool)" = "helper
other
tool"
