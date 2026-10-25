#include "harness_start.bash"

# A compiled script's rule names a file in the object directory that
# holds the recipe it was built with, which is how a change to its
# options gets it built again.  That file is pconfigure's, written at
# configure time and made by no rule of the build's own, so the two
# ways an object directory loses files have to leave the build able to
# go on: a cache clean has to spare it, which it does because the
# Makefile names it, or every script is rebuilt for nothing, and a
# deleted object directory has to get it back, or make stops with "No
# rule to make target".  And a reconfigure that changes nothing must
# not rewrite it, or every reconfigure rebuilds every script.
mkdir -p src

cat >src/tool.bash <<'EOF'
#!/bin/bash
echo GREETING
EOF

cat >Configfile <<EOF
LANGUAGES   += bash

BINARIES    += tool
COMPILEOPTS += -DGREETING=hello
SOURCES     += tool.bash
EOF

sleep 2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/tool)" = "hello"

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS > reconfigured.log 2>&1 || { cat reconfigured.log; exit 1; }
cat reconfigured.log
grep -q "Nothing to be done" reconfigured.log

make $MAKE_ARGS cache-clean
make $MAKE_ARGS > cache-cleaned.log 2>&1 || { cat cache-cleaned.log; exit 1; }
cat cache-cleaned.log
grep -q "Nothing to be done" cache-cleaned.log

rm -rf obj
make $MAKE_ARGS > deleted.log 2>&1 || { cat deleted.log; exit 1; }
cat deleted.log
test "$(./bin/tool)" = "hello"

make $MAKE_ARGS > settled.log 2>&1 || { cat settled.log; exit 1; }
cat settled.log
grep -q "Nothing to be done" settled.log

exit 0
