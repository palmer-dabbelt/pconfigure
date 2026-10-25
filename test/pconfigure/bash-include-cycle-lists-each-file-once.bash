#include "harness_start.bash"

# Two helpers that include each other are fine for pbashc, which never
# pastes the same file twice.  The scan for what the script depends on
# has to stop going around the cycle somewhere too: without that it
# follows it until it runs out of file descriptors, which is where it
# stops only by accident -- the rule for the script comes out with
# thousands of prerequisites, and with a higher descriptor limit the
# recursion runs off the end of the stack instead.
mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF2

cat >src/tool.bash <<'EOF2'
#include "a.bash"
echo tool
EOF2

cat >src/a.bash <<'EOF2'
#include "b.bash"
echo a
EOF2

cat >src/b.bash <<'EOF2'
#include "a.bash"
echo b
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
grep "^bin/tool:" Makefile | cut -c1-300

# Each file in the cycle is named exactly once, and nothing else is.
grep "^bin/tool:" Makefile | tr ' ' '\n' | grep '\.bash$' | sort > got
printf '%s\n' src/a.bash src/b.bash src/tool.bash > want
diff -u want got

make $MAKE_ARGS
test "$(./bin/tool)" = "b
a
tool"

# And both halves of the cycle are really prerequisites: editing the
# one that is only reached through the other still rebuilds.
sleep 1
cat >src/b.bash <<'EOF2'
#include "a.bash"
echo B
EOF2

make $MAKE_ARGS
test "$(./bin/tool)" = "B
a
tool"
