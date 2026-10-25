#include "harness_start.bash"

# "#ifndef" followed by a tab and then a space, which is what an
# editor mixing the two leaves behind, still asks about WITH_HELPER to
# the scan: it skips every blank after the keyword, sees the name
# COMPILEOPTS defines, and leaves fallback.bash off the script's
# prerequisites.  pbashc skipped exactly one character, compared
# " WITH_HELPER" against its -D's, found nothing, and pasted in the
# fallback that make was told the script doesn't read -- so an edit to
# it would never have rebuilt the script it ended up in.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash
COMPILEOPTS += -DWITH_HELPER

BINARIES  += tool
SOURCES   += tool.bash
EOF

printf '#ifndef\t WITH_HELPER\n#include "fallback.bash"\n#endif\necho tool\n' \
    >src/tool.bash

cat >src/fallback.bash <<'EOF'
echo fallback
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
grep "^bin/tool:" Makefile
if grep "^bin/tool:" Makefile | grep -q "src/fallback.bash"
then
    exit 1
fi

make $MAKE_ARGS
cat bin/tool
test "$(./bin/tool)" = "tool"
