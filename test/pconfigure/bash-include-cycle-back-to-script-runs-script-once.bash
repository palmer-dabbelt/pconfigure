#include "harness_start.bash"

# The manual says each file is pasted in at most once, so two files
# that include each other each come out once.  The file pbashc was
# asked to compile is not on its own list of what has been pasted,
# though: a helper that includes the script it was included from
# pastes the whole script in a second time, inside itself, and every
# line of the program runs twice.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

cat >src/tool.bash <<'EOF'
#include "helper.bash"
echo tool
EOF

cat >src/helper.bash <<'EOF'
#include "tool.bash"
echo helper
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/tool)" = "helper
tool"
