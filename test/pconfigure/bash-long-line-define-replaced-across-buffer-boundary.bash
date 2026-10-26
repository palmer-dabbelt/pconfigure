#include "harness_start.bash"

# "-DNAME=value" replaces NAME wherever it appears in the output, on a
# line of any length.  pbashc used to read its input 1023 bytes at a
# time and replace within each piece on its own, so a NAME that a long
# line happened to put across a piece boundary was written out as it
# was: a usage message that ran past a thousand characters printed
# "VERSION" rather than the version.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash
COMPILEOPTS += -DVERSION=1.2

BINARIES  += tool
SOURCES   += tool.bash
EOF

# 'echo "' is six characters, so 1014 more put VERSION's first letter
# at offset 1020 -- across the old boundary at 1023.
pad="$(printf '%1014s' '' | tr ' ' x)"
printf 'echo "%sVERSION"\n' "$pad" >src/tool.bash

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/tool)" = "${pad}1.2"
