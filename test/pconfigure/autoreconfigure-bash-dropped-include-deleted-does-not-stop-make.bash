#include "harness_start.bash"
#pconfigure TESTDEPS += bin/pdeps

# The other half of tracking a script's includes during the build: a
# file that a script stops including, and that is then deleted, is an
# ordinary edit to a source tree.  For C under AUTORECONFIGURE that is
# a recompile (see deleted-header-recompiles-not-stops.bash).  For a
# BASH script the Makefile still names the include as pconfigure found
# it at configure time, so make stops with "No rule to make target"
# on a file nothing reads any more, and nothing short of a reconfigure
# by hand gets the build going again.
export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src

cat >Configfile <<EOF
AUTORECONFIGURE = true

LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

cat >src/lib.bash <<'EOF'
echo lib
EOF

cat >src/tool.bash <<'EOF'
#!/bin/bash
#include "lib.bash"
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/tool)" = "lib"

sleep 2
cat >src/tool.bash <<'EOF'
#!/bin/bash
echo standalone
EOF
rm src/lib.bash

make $MAKE_ARGS
test "$(./bin/tool)" = "standalone"

exit 0
