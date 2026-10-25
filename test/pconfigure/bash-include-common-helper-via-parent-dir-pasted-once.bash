#include "harness_start.bash"

# A script and a helper in a subdirectory both include the same
# common file, each spelled from its own directory: "common.bash" from
# src/, "../common.bash" from src/lib/.  It is one file, and the
# manual promises each file is pasted in at most once.  pbashc keeps
# its list of what it pasted by the path as spelled, src/common.bash
# against src/lib/../common.bash, so it pastes the file twice -- and a
# file that sets a readonly variable then fails the second time.
mkdir -p src/lib

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

cat >src/tool.bash <<'EOF'
#include "common.bash"
#include "lib/extra.bash"
echo "tool $NAME"
EOF

cat >src/lib/extra.bash <<'EOF'
#include "../common.bash"
echo extra
EOF

cat >src/common.bash <<'EOF'
readonly NAME=common
echo common
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/tool 2>&1)" = "common
extra
tool common"
