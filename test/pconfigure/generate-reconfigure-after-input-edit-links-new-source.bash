#include "harness_start.bash"

# The same staleness reached through the script's input rather than
# the script: gen.h is a copy of a file the script names with --deps,
# and it is that file the user edits.  The rerun pconfigure has to
# scan what the edited input makes, not what the old one made, or the
# include it gained is followed nowhere and helper.c is never linked.

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
--deps)     echo "src/gen.h.in" ;;
--generate) cat src/gen.h.in ;;
esac
EOF
chmod +x src/gen.h.proc

cat >src/gen.h.in <<'EOF'
static int answer(void) { return 1; }
EOF

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
cat >src/gen.h.in <<'EOF'
#include "../../src/helper.h"
static int answer(void) { return helper(); }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "7"

exit 0
