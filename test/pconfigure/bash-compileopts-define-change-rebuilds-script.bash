#include "harness_start.bash"

# pbashc replaces a "-DNAME=value" in the script it compiles, so the
# value is part of what comes out.  A C object follows a change to its
# COMPILEOPTS because the options are hashed into the object's path,
# which makes a changed flag a new target.  A compiled script is
# written straight to bin/ under its own name, so the rule is the same
# rule with a different recipe, and make does not rebuild a target
# because its recipe changed.  The script used to go on saying the old
# value until somebody happened to touch the source; the recipe is now
# written down in a file the rule names, and that file changing is the
# reason make needs.
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

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/tool)" = "hello"

sleep 2
cat >Configfile <<EOF
LANGUAGES   += bash

BINARIES    += tool
COMPILEOPTS += -DGREETING=goodbye
SOURCES     += tool.bash
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
grep -q "pbashc .*-DGREETING=goodbye" Makefile

make $MAKE_ARGS
test "$(./bin/tool)" = "goodbye"

exit 0
