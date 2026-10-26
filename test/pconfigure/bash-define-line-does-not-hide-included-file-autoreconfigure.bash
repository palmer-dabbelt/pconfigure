#include "harness_start.bash"

# The "#define" line pbashc ignores, under AUTORECONFIGURE, where it is
# pdeps that works out what the script includes.  It uses the same
# scan, which took the "#define" for real and left the file pbashc
# pastes in off the list, so an edit to it never rebuilt the script.

mkdir -p src

cat >Configfile <<'EOF'
AUTORECONFIGURE = true
LANGUAGES   += bash

BINARIES    += app
SOURCES     += app.bash
EOF

cat >src/app.bash <<'EOF'
#!/bin/bash
#define QUIET
#ifndef QUIET
#include "extra.bash"
#endif
echo main
EOF
echo 'echo extra-one' > src/extra.bash

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
./bin/app | grep -qx extra-one

sleep 1
echo 'echo extra-two' > src/extra.bash
make $MAKE_ARGS
./bin/app
./bin/app | grep -qx extra-two
