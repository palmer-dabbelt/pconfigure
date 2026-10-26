#include "harness_start.bash"

# The SRCDIR above a GENERATE picks which script it runs.  Moving the
# line under a different SRCDIR points it at a different script, but
# the output that the first script wrote is newer than the second, so
# the rule is satisfied and the second script never runs: the build
# goes on using a header from a script the Configfile no longer names.

mkdir -p src other

cat >src/gen.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--generate) echo "#define V 1" ;;
esac
EOF
cat >other/gen.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--generate) echo "#define V 2" ;;
esac
EOF
chmod +x src/gen.h.proc other/gen.h.proc

cat >src/app.c <<'EOF'
#include "gen.h"
#include <stdio.h>
int main(void) { printf("%d\n", V); return 0; }
EOF

cat >Configfile <<EOF
LANGUAGES += c
GENERATE  += gen.h
BINARIES  += app
SOURCES   += app.c
EOF

sleep 2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "1"

cat >Configfile <<EOF
LANGUAGES += c
SRCDIR     = other
GENERATE  += gen.h
SRCDIR     = src
BINARIES  += app
SOURCES   += app.c
EOF
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "2"

exit 0
