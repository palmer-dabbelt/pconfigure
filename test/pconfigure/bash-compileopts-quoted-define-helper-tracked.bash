#include "harness_start.bash"

# -D"FANCY" is -DFANCY by the time pbashc sees it, so the "#ifdef FANCY"
# branch is taken and fancy.bash is pasted in.  The dependency scan
# reads the same COMPILEOPTS, and if it keeps the quotes it decides
# the branch isn't taken and leaves fancy.bash off the script's
# prerequisites -- so an edit to it never reaches the script.

mkdir -p src

cat >Configfile <<'EOC'
LANGUAGES   += bash
BINARIES    += tool
COMPILEOPTS += -D"FANCY"
SOURCES     += tool.bash
EOC

cat >src/tool.bash <<'EOC'
#ifdef FANCY
#include "fancy.bash"
#endif
EOC

echo 'echo old' > src/fancy.bash

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(bash bin/tool)" = "old"

sleep 1
echo 'echo new' > src/fancy.bash
make $MAKE_ARGS
test "$(bash bin/tool)" = "new"
