#include "harness_start.bash"

# TGENERATE is GENERATE with the script in test/, and shares its
# --srcpath trouble: the script is found in the source tree but run
# from the build directory, so a fixture script that reads
# test/fixture.txt -- spelled, as the manual says, from the top of its
# project -- can't find it, and the --deps path it prints is left
# unrooted in the Makefile.

mkdir -p tree/test tree/src build

cat >tree/Configfile <<EOF
LANGUAGES += c
TGENERATE += fixture.h
BINARIES  += app
SOURCES   += app.c
EOF

echo 6 > tree/test/fixture.txt

cat >tree/test/fixture.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--deps)     echo "test/fixture.txt" ;;
--generate) echo "#define FIXTURE $(cat test/fixture.txt)" ;;
esac
EOF
chmod +x tree/test/fixture.h.proc

cat >tree/src/app.c <<'EOF'
#include "fixture.h"
#include <stdio.h>
int main(void) { printf("%d\n", FIXTURE); return 0; }
EOF

cd build
$PTEST_BINARY $PCONFIGURE_ARGS --srcpath ../tree
make $MAKE_ARGS
test "$(./bin/app)" = "6"

exit 0
