#include "harness_start.bash"

# TGENERATE is GENERATE with the script taken from the test directory
# rather than the source directory: a generator that only exists to
# build fixtures for the tests belongs with the tests.  The command was
# parsed, and then refused as "not implemented" with no Configfile line
# attached, so a project that followed the manual got an abort and no
# idea which line had caused it.
#
# There is a src/gen.h.proc here as well, giving a different answer,
# so that the build saying 9 means the script under test/ is the one
# that ran -- not that both directories happen to be looked in.

mkdir -p src test

cat >Configfile <<EOF
LANGUAGES  += c

TGENERATE  += gen.h

BINARIES   += app
SOURCES    += app.c
EOF

cat >test/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--generate) echo "#define ANSWER 9" ;;
esac
EOF
chmod +x test/gen.h.proc

cat >src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--generate) echo "#define ANSWER 1" ;;
esac
EOF
chmod +x src/gen.h.proc

cat >src/app.c <<'EOF'
  #include "gen.h"
  #include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "9"

# The script under test/ is the rule's prerequisite too, not just the
# thing its recipe runs: an edit to it is heard by a plain make, the
# same way an edit to a GENERATE's script is.
sleep 2
cat >test/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--generate) echo "#define ANSWER 19" ;;
esac
EOF
chmod +x test/gen.h.proc

make $MAKE_ARGS
test "$(./bin/app)" = "19"

exit 0
