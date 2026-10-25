#include "harness_start.bash"

# pbashc is run through the shell, so -I'lib' reaches it as -Ilib and
# the helper in lib/ is pasted into the script.  The script's list of
# prerequisites is worked out by reading the same options, and has to
# take the quotes off the same way, or the pasted helper is missing
# from it and editing the helper leaves the built script stale.

mkdir -p src lib

cat >Configfile <<'EOC'
LANGUAGES   += bash
COMPILEOPTS += -I'lib'
BINARIES    += tool
SOURCES     += tool.bash
EOC

cat >src/tool.bash <<'EOC'
#!/bin/bash
#include "helper.bash"
helper
EOC

echo 'helper() { echo one; }' > lib/helper.bash

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/tool)" = "one"

sleep 1
echo 'helper() { echo two; }' > lib/helper.bash
make $MAKE_ARGS
test "$(./bin/tool)" = "two"
