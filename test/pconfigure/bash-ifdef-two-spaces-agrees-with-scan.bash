#include "harness_start.bash"

# "#ifdef  WITH_HELPER", with two spaces, asks about WITH_HELPER to
# pconfigure's scan, which trims the blanks after the keyword and
# lists helper.bash because COMPILEOPTS defines the name.  pbashc
# compares " WITH_HELPER", leading space and all, against its -D's,
# finds nothing, and leaves the include out: the two disagree about
# what the script is made of, and the script comes out without the
# helper that make was told it depends on.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash
COMPILEOPTS += -DWITH_HELPER

BINARIES  += tool
SOURCES   += tool.bash
EOF

printf '%s\n' \
    '#ifdef  WITH_HELPER' \
    '#include "helper.bash"' \
    '#endif' \
    'echo tool' \
    >src/tool.bash

cat >src/helper.bash <<'EOF'
echo helper
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
grep "^bin/tool:" Makefile | grep -q "src/helper.bash"

make $MAKE_ARGS
cat bin/tool
test "$(./bin/tool)" = "helper
tool"
