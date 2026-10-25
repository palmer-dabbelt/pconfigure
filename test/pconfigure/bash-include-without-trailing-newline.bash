#include "harness_start.bash"

# Plenty of editors save a file without a newline at the end.  An
# included file is pasted into the script a line at a time, so when the
# helper's last line has no newline the next line of the including
# script used to be glued straight onto it: "greet() { ...; }" and
# "greet" became "greet() { ...; }greet", and the compiled script was a
# syntax error.  A file's last line ends where the file does.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

printf 'greet() { echo hello; }' > src/helper.bash

cat >src/tool.bash <<'EOF'
#include "helper.bash"
greet
echo tool
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/tool)" = "hello
tool"

# The same goes one level further down, where what follows the
# unterminated line is the rest of another included file rather than
# the top-level script.
printf 'inner() { echo inner; }' > src/inner.bash
cat >src/helper.bash <<'EOF'
#include "inner.bash"
greet() { inner; echo hello; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/tool)" = "inner
hello
tool"

# A line longer than the buffer it is read in arrives in pieces, none
# of which but the last has a newline either.  Those pieces are one
# line and have to stay one: only the end of the file ends a line that
# didn't end itself.
long="$(head -c 3000 /dev/zero | tr '\0' x)"
printf 'greet() { echo %s; }' "$long" > src/helper.bash

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/tool)" = "$long
tool"
