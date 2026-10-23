#include "harness_start.bash"

# A "-D" in COMPILEOPTS reaches pbashc, and pbashc's "#ifdef" reads it:
# the includes below are pasted in because their names are defined.
# The dependency scan has to know the same thing, or it decides an
# include is in a branch that isn't taken and leaves the helper off the
# list -- and then an edit to the helper never reaches the script.
#
# One name is defined stuck on, one as the word after the "-D" and one
# with a value, which are the three ways a "-D" defines a name.
mkdir -p src

cat >Configfile <<EOF
LANGUAGES   += bash

BINARIES    += tool
COMPILEOPTS += -DFANCY
COMPILEOPTS += -D PLAIN
COMPILEOPTS += -DVALUED=yes
SOURCES     += tool.bash
EOF

cat >src/tool.bash <<'EOF'
#ifdef FANCY
#include "fancy.bash"
#endif
#ifdef PLAIN
#include "plain.bash"
#endif
#ifdef VALUED
#include "valued.bash"
#endif
#ifdef MISSING
#include "missing.bash"
#endif
echo tool
EOF

cat >src/fancy.bash <<'EOF'
echo old
EOF

cat >src/plain.bash <<'EOF'
echo plain
EOF

cat >src/valued.bash <<'EOF'
echo valued
EOF

cat >src/missing.bash <<'EOF'
echo missing
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

grep "^bin/tool:" Makefile | grep -q "src/fancy.bash"
grep "^bin/tool:" Makefile | grep -q "src/plain.bash"
grep "^bin/tool:" Makefile | grep -q "src/valued.bash"

# A name nobody defined still leaves its branch out, of the script
# and of the list alike.
if grep "^bin/tool:" Makefile | grep -q "src/missing.bash"
then
    exit 1
fi

make $MAKE_ARGS
test "$(./bin/tool)" = "old
plain
valued
tool"

sleep 1
cat >src/fancy.bash <<'EOF'
echo new
EOF

make $MAKE_ARGS
cat bin/tool
test "$(./bin/tool)" = "new
plain
valued
tool"

exit 0
