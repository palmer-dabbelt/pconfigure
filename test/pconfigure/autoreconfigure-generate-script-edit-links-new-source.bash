#include "harness_start.bash"

# Under AUTORECONFIGURE the build works out which headers a source
# reads, generated ones included, so a GENERATE script edited to make
# its header include another header -- one with a source behind it --
# gets that source compiled and linked by the next plain make, with no
# reconfigure.  This is the behaviour a project without
# AUTORECONFIGURE is told to rerun pconfigure for.

mkdir -p src

cat >Configfile <<EOF
AUTORECONFIGURE = true
LANGUAGES += c
GENERATE  += gen.h
BINARIES  += app
SOURCES   += app.c
EOF

cat >src/gen.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--generate) echo "static int answer(void) { return 1; }" ;;
esac
EOF
chmod +x src/gen.h.proc

cat >src/helper.h <<'EOF'
int helper(void);
EOF

cat >src/helper.c <<'EOF'
int helper(void) { return 7; }
EOF

cat >src/app.c <<'EOF'
#include "gen.h"
#include <stdio.h>
int main(void) { printf("%d\n", answer()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "1"

sleep 2
cat >src/gen.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--generate) echo '#include "../../src/helper.h"'
            echo "static int answer(void) { return helper(); }" ;;
esac
EOF

make $MAKE_ARGS > again.out 2>&1
cat again.out
grep -q "^CC	helper.c$" again.out
test "$(./bin/app)" = "7"

exit 0
