#include "harness_start.bash"
#pconfigure TESTDEPS += bin/pdeps

# An include can change which file it reads without the script or any
# file it reads getting newer: with "-Ia -Ib" a "lib.bash" in a/ hides
# the one in b/, and deleting a/'s copy hands the include to b/'s,
# which is older than the compiled script.  Under AUTORECONFIGURE the
# build is told what the script reads by a list pdeps writes, and the
# list changing is what has to rebuild the script -- the files on it
# can't say so by themselves.
export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src a b

cat >Configfile <<EOF
AUTORECONFIGURE = true

LANGUAGES   += bash

BINARIES    += tool
COMPILEOPTS += -Ia -Ib
SOURCES     += tool.bash
EOF

cat >b/lib.bash <<'EOF'
echo b
EOF

sleep 2
cat >a/lib.bash <<'EOF'
echo a
EOF

cat >src/tool.bash <<'EOF'
#!/bin/bash
#include "lib.bash"
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/tool)" = "a"

sleep 2
rm a/lib.bash
make $MAKE_ARGS
test "$(./bin/tool)" = "b"

# And having followed it, the build settles.
make $MAKE_ARGS > settled.out 2>&1
cat settled.out
grep -q "Nothing to be done" settled.out

exit 0
