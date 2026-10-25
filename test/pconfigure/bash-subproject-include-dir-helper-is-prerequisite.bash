#include "harness_start.bash"

# The list of what a BASH script reads is found by searching its "-I"
# directories the way pbashc does, so in a subproject that search has
# to be rerooted along with the recipe.  Searching "inc" from the top
# of the tree finds nothing there, so the helper the script pastes in
# was left off the script's prerequisites, and editing the helper
# never rebuilt the script.
mkdir -p sub/src sub/inc

cat >Configfile <<'EOF2'
SUBPROJECTS += sub
EOF2

cat >sub/Configfile <<'EOF2'
LANGUAGES   += bash

BINARIES    += tool
COMPILEOPTS += -I inc
SOURCES     += tool.bash
EOF2

cat >sub/src/tool.bash <<'EOF2'
#include "helper.bash"
echo tool
EOF2

cat >sub/inc/helper.bash <<'EOF2'
echo old
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./sub/bin/tool)" = "old
tool"

sleep 1
cat >sub/inc/helper.bash <<'EOF2'
echo new
EOF2

make $MAKE_ARGS
test "$(./sub/bin/tool)" = "new
tool"
