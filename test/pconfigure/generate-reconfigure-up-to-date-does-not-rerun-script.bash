#include "harness_start.bash"

# A rerun of pconfigure regenerates a GENERATE output only when make
# would: when the script or one of its inputs is newer than what is
# there.  An output that is up to date is left alone, so a script
# that is expensive to run costs nothing to a reconfigure that changed
# nothing it reads.  The script counts its own runs to say so.

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
--generate) echo run >> generate-runs
            cat src/gen.h.in ;;
esac
EOF
chmod +x src/gen.h.proc

echo "#define ANSWER 1" > src/gen.h.in

cat >src/app.c <<'EOF'
#include "gen.h"
#include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "1"
test "$(wc -l < generate-runs | tr -d ' ')" = "1"

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(wc -l < generate-runs | tr -d ' ')" = "1"

exit 0
