#include "harness_start.bash"

# pbashc looks for an '#include "x.bash"' beside the script before it
# looks down the -I list, the way a C compiler does, so a src/x.bash
# written after the first build is what the script pastes in from then
# on.  A reconfigure without AUTORECONFIGURE picks it up.  Under
# AUTORECONFIGURE the script's fragment named only inc/x.bash, and
# nothing -- not make, not pconfigure -- rewrote it, so bin/app kept
# the old text.

mkdir -p src inc

cat >Configfile <<'EOC'
AUTORECONFIGURE  = true
LANGUAGES       += bash
BINARIES        += app
COMPILEOPTS     += -Iinc
SOURCES         += app.bash
EOC

echo 'echo 1' > inc/x.bash

cat >src/app.bash <<'EOS'
#!/bin/bash
#include "x.bash"
EOS

$PTEST_BINARY $PCONFIGURE_ARGS
timeout 60 make $MAKE_ARGS
test "$(./bin/app)" = "1"

sleep 2
echo 'echo 2' > src/x.bash

$PTEST_BINARY $PCONFIGURE_ARGS
timeout 60 make $MAKE_ARGS
test "$(./bin/app)" = "2"

timeout 60 make $MAKE_ARGS > settled.out 2>&1
cat settled.out
grep -q "Nothing to be done" settled.out
