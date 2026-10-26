#include "harness_start.bash"

# A subproject's SRCPATH moves the top of that subproject's source tree
# the way "--srcpath" moves the top-level one, so its GENERATE script is
# run from "sub/tree" and the --deps paths it prints are rooted there.
# The dependency fragment spells that root as the subproject's variable
# followed by the SRCPATH, and the second half going missing is what
# left the fragment naming "sub/src/answer.txt", which nothing builds.
# The edit at the end is what proves the fragment's spelling is right:
# only a correctly rooted prerequisite regenerates the header.

mkdir -p sub/tree/src

cat >Configfile <<EOF
LANGUAGES   += c
SUBPROJECTS += sub
EOF

cat >sub/Configfile <<EOF
SRCPATH    = tree
LANGUAGES += c
GENERATE  += gen.h
BINARIES  += app
SOURCES   += app.c
EOF

echo 4 > sub/tree/src/answer.txt

cat >sub/tree/src/gen.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--deps)     echo "src/answer.txt" ;;
--generate) echo "#define ANSWER $(cat src/answer.txt)" ;;
esac
EOF
chmod +x sub/tree/src/gen.h.proc

cat >sub/tree/src/app.c <<'EOF'
#include "gen.h"
#include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./sub/bin/app)" = "4"

sleep 2
echo 5 > sub/tree/src/answer.txt
make $MAKE_ARGS
test "$(./sub/bin/app)" = "5"

exit 0
