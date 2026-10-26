#include "harness_start.bash"

# pconfigure works out which sources to link by reading the headers a
# program includes, generated ones among them, and it reads the
# generated header that is sitting in obj/proc when it runs.  It only
# runs the script to make one when there is none there, so a rerun
# after the script was edited reads what the OLD script printed.
#
# Here the edited script makes gen.h include a header whose source has
# to be linked in.  The user did the thing the manual asks for after a
# change like this -- ran pconfigure again -- and the very next make is
# expected to link helper.c in rather than to fail with an undefined
# reference that only a second pconfigure clears.

mkdir -p src

cat >Configfile <<EOF
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

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "7"

exit 0
