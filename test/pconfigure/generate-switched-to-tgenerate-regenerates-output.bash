#include "harness_start.bash"

# Which script makes a GENERATE's output is decided by the Configfile:
# GENERATE runs src/<name>.proc and TGENERATE runs test/<name>.proc.
# Changing one into the other changes the recipe and the script on the
# rule, but the output on disk was written by the old script and is
# newer than the new one, so make calls it up to date -- and pconfigure
# only runs a script itself when the output is missing.  The program
# keeps the old script's answer until somebody runs make clean.  Other
# outputs whose recipe changes under them (pbashc scripts, HEADERS
# copies) keep a record of the recipe for exactly this.

mkdir -p src test

cat >src/gen.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--generate) echo "#define V 1" ;;
esac
EOF
cat >test/gen.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--generate) echo "#define V 2" ;;
esac
EOF
chmod +x src/gen.h.proc test/gen.h.proc

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

# Both scripts are older than anything the build writes, which is the
# ordinary state of a checkout.
sleep 2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "1"

sed -i 's/^GENERATE /TGENERATE /' Configfile
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "2"

exit 0
