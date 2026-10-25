#include "harness_start.bash"
#pconfigure TESTDEPS += bin/pdeps

# AUTORECONFIGURE is documented as moving "what a source depends on"
# out of pconfigure and into the build, so that "a source growing an
# #include" is noticed without a reconfigure.  A BASH script's
# includes are its dependencies in exactly that sense -- pbashc pastes
# them in -- but the Makefile still lists them as pconfigure found
# them at configure time.  A script that starts including a file
# after that is recompiled once, because the script itself changed,
# and then never again when the file it now includes is edited.
export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src

cat >Configfile <<EOF
AUTORECONFIGURE = true

LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

cat >src/tool.bash <<'EOF'
#!/bin/bash
echo plain
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/tool)" = "plain"

# The script grows an include.  This build is fine either way, since
# the script itself is newer than what was compiled from it.
sleep 2
cat >src/lib.bash <<'EOF'
echo first
EOF
cat >src/tool.bash <<'EOF'
#!/bin/bash
#include "lib.bash"
EOF
make $MAKE_ARGS
test "$(./bin/tool)" = "first"

# The file it now includes changes, and the compiled script has to
# follow it.
sleep 2
cat >src/lib.bash <<'EOF'
echo second
EOF
make $MAKE_ARGS
test "$(./bin/tool)" = "second"

exit 0
