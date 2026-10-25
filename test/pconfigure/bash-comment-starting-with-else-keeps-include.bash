#include "harness_start.bash"

# pbashc used to decide a line was "#else" by its first five characters
# alone, so a comment written against its '#' that happened to begin
# with those letters -- "#elsewhere" -- flipped the state of a
# conditional that wasn't there.  Every include after it was dropped,
# and the script came out without them and still exited zero.  The
# dependency scan wants the keyword to end where a word does, so it
# disagreed and listed the helper as a prerequisite all the same.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

cat >src/tool.bash <<'EOF'
#elsewhere this was sourced at run time
#include "helper.bash"
echo tool
EOF

cat >src/helper.bash <<'EOF'
echo helper
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
cat bin/tool
test "$(./bin/tool)" = "helper
tool"
