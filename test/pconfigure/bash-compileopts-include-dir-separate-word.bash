#include "harness_start.bash"

# "-I dir" as two words is how most people write an include directory,
# and it is what the C languages already accept.  pbashc only knows the
# glued "-Idir" spelling: the lone "-I" becomes an empty directory and
# the "dir" after it is taken for the input file.  Being a directory it
# opens and reads as nothing, so what comes out is a shebang and an
# empty script, built without a word of complaint.
mkdir -p src inc

cat >Configfile <<EOF
LANGUAGES   += bash

BINARIES    += tool
COMPILEOPTS += -I inc
SOURCES     += tool.bash
EOF

cat >src/tool.bash <<'EOF'
#include "helper.bash"
echo tool
EOF

cat >inc/helper.bash <<'EOF'
echo helper
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
cat bin/tool
test "$(./bin/tool)" = "helper
tool"

exit 0
