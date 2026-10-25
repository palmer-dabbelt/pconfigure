#include "harness_start.bash"

# A directory beside the script that happens to share an include's
# name is not the file the include means.  The search carries on into
# the "-I" directories the way it would for a name that isn't there at
# all, both when pbashc pastes the file in and when pconfigure lists
# what the script depends on -- otherwise the script compiles with
# nothing where the helper should be, and make watches the directory
# instead of the helper.
mkdir -p src/helper inc

cat >Configfile <<'EOF'
LANGUAGES   += bash

BINARIES    += tool
COMPILEOPTS += -Iinc
SOURCES     += tool.bash
EOF

cat >src/tool.bash <<'EOF'
#include "helper"
echo tool
EOF

cat >inc/helper <<'EOF'
echo helper
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

grep "^bin/tool:" Makefile | grep -q "inc/helper"
if grep "^bin/tool:" Makefile | grep -q "src/helper"
then
    exit 1
fi

make $MAKE_ARGS
cat bin/tool
test "$(./bin/tool)" = "helper
tool"
