#include "harness_start.bash"

# A TGENERATE inside a subproject takes its script from that
# subproject's own test directory, and runs it from the top of that
# subproject, exactly as a GENERATE there takes and runs its script
# from the subproject's source directory.  The test directory moves
# with the project the same way the source directory does, so this is
# the case that would notice the script being looked for under the
# parent's test/ instead.

mkdir -p sub/src sub/test

cat >Configfile <<EOF
SUBPROJECTS += sub
EOF

cat >sub/Configfile <<EOF
LANGUAGES  += c

TGENERATE  += gen.h
BINARIES   += app
SOURCES    += app.c
EOF

cat >sub/test/answer.txt <<EOF
42
EOF

cat >sub/test/gen.h.proc <<"EOF"
#!/bin/bash
case "$1" in
--deps)     echo "test/answer.txt" ;;
--generate) echo "#define ANSWER $(cat test/answer.txt)" ;;
esac
EOF
chmod +x sub/test/gen.h.proc

cat >sub/src/app.c <<EOF
  #include <stdio.h>
  #include "gen.h"
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat sub/obj/Makefile.sub

grep -q "cd .*sub.* && test/gen.h.proc --generate" sub/obj/Makefile.sub

make $MAKE_ARGS
test "$(./sub/bin/app)" = "42"

exit 0
