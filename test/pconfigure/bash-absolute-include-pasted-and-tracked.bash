#include "harness_start.bash"

# pbashc and the dependency scan share the lookup that put the
# includer's directory in front of an absolute "#include", so a script
# that named a helper by its full path was refused by pbashc as a file
# it couldn't open.  The path is the file: pasted from there, and
# editing it rebuilds the script.

mkdir -p src shared

cat >src/x.bash <<EOF2
#include "$tempdir/shared/l.bash"
hello
EOF2
echo 'hello() { echo one; }' > shared/l.bash

cat >Configfile <<'EOF2'
LANGUAGES += bash
BINARIES  += x
SOURCES   += x.bash
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/x)" = one

sleep 1
echo 'hello() { echo two; }' > shared/l.bash
make $MAKE_ARGS
test "$(./bin/x)" = two
