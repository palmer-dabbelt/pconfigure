#include "harness_start.bash"

# A script's includes under AUTORECONFIGURE are written by pdeps into a
# fragment while the build runs, as prerequisites of the compiled
# script and with an empty rule each.  "my helper.bash" went in bare
# there, and make split it at the space on both.
#
# The script is written with printf, since a '#' in the first column
# of this file is a directive for this file.

mkdir -p src

cat >Configfile <<'EOF2'
AUTORECONFIGURE = true
LANGUAGES   += bash

BINARIES    += app
SOURCES     += app.bash
EOF2

printf '%s\n' '#!/bin/bash' '#include "my helper.bash"' 'echo main' \
    > src/app.bash
echo 'echo helper-one' > 'src/my helper.bash'

$PTEST_BINARY $PCONFIGURE_ARGS
timeout 120 make $MAKE_ARGS
./bin/app | grep -qx helper-one

sleep 1
echo 'echo helper-two' > 'src/my helper.bash'
timeout 120 make $MAKE_ARGS
./bin/app | grep -qx helper-two
