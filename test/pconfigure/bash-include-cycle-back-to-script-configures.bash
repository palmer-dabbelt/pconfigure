#include "harness_start.bash"

# A helper that includes the script that included it closes a cycle
# through the file the scan started from.  That file is the one being
# read the whole time, so the scan has to know it is already in the
# middle of it; otherwise it goes round once more and names the script
# as a prerequisite of itself on top of everything else.
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
#include "tool.bash"
echo a
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
grep "^bin/tool:" Makefile | cut -c1-300

grep "^bin/tool:" Makefile | tr ' ' '\n' | grep '\.bash$' | sort > got
printf '%s\n' src/a.bash src/tool.bash > want
diff -u want got
