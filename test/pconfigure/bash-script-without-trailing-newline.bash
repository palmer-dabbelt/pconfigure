#include "harness_start.bash"

# The script being compiled can end without a newline as easily as
# anything it includes.  Bash runs that happily enough, but the
# compiled script is a text file like any other and its last line
# should end like one: anything that appends to it, or cats it
# together with something else, otherwise gets the same gluing an
# unterminated include used to cause.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

printf 'echo first\necho last' > src/tool.bash

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/tool)" = "first
last"
test "$(tail -c 1 bin/tool | od -An -c | tr -d ' ')" = '\n'
