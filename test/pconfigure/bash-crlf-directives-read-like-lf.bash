#include "harness_start.bash"

# Directive lines that came from a Windows editor end in "\r\n".  The
# "\r" is no part of the name an "#ifdef" asks about or of the
# keyword in an "#endif", so the conditional reads as it would with
# plain newlines, in pbashc and in pconfigure's scan alike.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash
COMPILEOPTS += -DWITH_HELPER

BINARIES  += tool
SOURCES   += tool.bash
EOF

printf '#ifdef WITH_HELPER\r\n#include "helper.bash"\r\n#endif\r\n' \
    >src/tool.bash
printf '#ifndef WITH_HELPER\r\n#include "other.bash"\r\n#endif\r\n' \
    >>src/tool.bash
echo 'echo tool' >>src/tool.bash

echo 'echo helper' >src/helper.bash
echo 'echo other' >src/other.bash

$PTEST_BINARY $PCONFIGURE_ARGS
grep "^bin/tool:" Makefile | grep -q "src/helper.bash"
if grep "^bin/tool:" Makefile | grep -q "src/other.bash"
then
    exit 1
fi

make $MAKE_ARGS
test "$(./bin/tool)" = "helper
tool"
