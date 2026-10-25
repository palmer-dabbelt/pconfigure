#include "harness_start.bash"

# An include that names a directory -- "lib" when the file meant was
# "lib/strings.bash" -- used to pass pbashc's access() check, open,
# and read as nothing, so the script compiled with nothing pasted in
# where the include was and pbashc exited zero.  That is the failure
# pbashc already refuses for an input that is a directory, and the
# same reasoning applies: a script with a piece silently missing is
# the worst way for this to go wrong.  So the include has to be an
# error that points at the line, and the directory must not turn up
# as one of the script's prerequisites either.
mkdir -p src/lib

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

cat >src/lib/strings.bash <<'EOF'
greet() { echo hello; }
EOF

cat >src/tool.bash <<'EOF'
#include "lib"
echo tool
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
if grep "^bin/tool:" Makefile | grep -q "src/lib\( \|$\)"
then
    exit 1
fi

if make $MAKE_ARGS > make.out 2>&1
then
    cat make.out
    cat bin/tool
    exit 1
fi
cat make.out
grep -q "src/tool.bash:1:" make.out
grep -q "src/lib.*directory" make.out
