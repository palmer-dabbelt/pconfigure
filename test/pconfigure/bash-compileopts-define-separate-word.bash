#include "harness_start.bash"

# "-D name" as two words is the other half of what the C languages
# take and pbashc did not.  The lone "-D" became an empty definition
# and the "GREETING=hello" after it, being a bare word, took the place
# of the script that was meant to be compiled -- so what got built
# depended on whether a file of that name happened to exist.
mkdir -p src

cat >Configfile <<EOF
LANGUAGES   += bash

BINARIES    += tool
COMPILEOPTS += -D GREETING=hello
SOURCES     += tool.bash
EOF

cat >src/tool.bash <<'EOF'
echo GREETING
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
cat bin/tool
test "$(./bin/tool)" = "hello"

exit 0
