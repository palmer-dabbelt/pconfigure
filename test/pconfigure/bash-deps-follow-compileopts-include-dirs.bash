#include "harness_start.bash"

# pbashc is handed the target's COMPILEOPTS, so a "-I" there is a
# directory it really does look in for an "#include".  The list of
# files make is told the script depends on has to come from the same
# search, or a helper found through that "-I" is pasted into the
# script once and never again: editing it leaves the compiled script
# exactly as it was.
#
# Both spellings of the flag are here, since pbashc reads both and a
# scan that only knew one would lose the other's helper.
mkdir -p src inc other

cat >Configfile <<EOF
LANGUAGES   += bash

BINARIES    += tool
COMPILEOPTS += -Iinc
COMPILEOPTS += -I other
SOURCES     += tool.bash
EOF

cat >src/tool.bash <<'EOF'
#include "helper.bash"
#include "second.bash"
echo tool
EOF

cat >inc/helper.bash <<'EOF'
echo old
EOF

cat >other/second.bash <<'EOF'
echo second
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

grep "^bin/tool:" Makefile | grep -q "inc/helper.bash"
grep "^bin/tool:" Makefile | grep -q "other/second.bash"

make $MAKE_ARGS
test "$(./bin/tool)" = "old
second
tool"

sleep 1
cat >inc/helper.bash <<'EOF'
echo new
EOF

make $MAKE_ARGS
cat bin/tool
test "$(./bin/tool)" = "new
second
tool"

sleep 1
cat >other/second.bash <<'EOF'
echo changed
EOF

make $MAKE_ARGS
cat bin/tool
test "$(./bin/tool)" = "new
changed
tool"

exit 0
