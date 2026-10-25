#include "harness_start.bash"

# pbashc is run through the shell, so -I'inc' reaches it as -Iinc and
# the helper in inc/ is pasted into the script.  The script's list of
# prerequisites is worked out by reading the same options, and has to
# take the quotes off the same way, or the pasted helper is missing
# from it and editing the helper leaves the built script stale.

mkdir -p src inc

cat >Configfile <<'EOC'
LANGUAGES   += bash
COMPILEOPTS += -I'inc'
BINARIES    += tool
SOURCES     += tool.bash
EOC

cat >src/tool.bash <<'EOC'
#!/bin/bash
#include "helper.bash"
helper
EOC

echo 'helper() { echo one; }' > inc/helper.bash

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/tool)" = "one"

sleep 1
echo 'helper() { echo two; }' > inc/helper.bash
make $MAKE_ARGS
test "$(./bin/tool)" = "two"
