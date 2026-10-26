#include "harness_start.bash"

# A quoted include is looked for beside the including file before any
# -I directory.  With a helper.bash in both src/ and inc/, pbashc
# pastes src/'s, and pconfigure lists src/'s as the prerequisite --
# not inc/'s, whose edits mean nothing to the script.
mkdir -p src inc

cat >Configfile <<'EOF'
LANGUAGES += bash
COMPILEOPTS += -Iinc

BINARIES  += tool
SOURCES   += tool.bash
EOF

cat >src/tool.bash <<'EOF'
#include "helper.bash"
echo tool
EOF

echo 'echo src-helper' >src/helper.bash
echo 'echo inc-helper' >inc/helper.bash

$PTEST_BINARY $PCONFIGURE_ARGS
grep "^bin/tool:" Makefile | grep -q "src/helper.bash"
if grep "^bin/tool:" Makefile | grep -q "inc/helper.bash"
then
    exit 1
fi

make $MAKE_ARGS
test "$(./bin/tool)" = "src-helper
tool"
