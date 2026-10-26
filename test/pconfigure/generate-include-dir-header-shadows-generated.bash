#include "harness_start.bash"

# The project's include/ comes before obj/proc on the compile line, so
# an include/gen.h hides a GENERATE output of the same name from every
# source.  The dependency scan has to resolve "gen.h" in that same
# order: the object depends on include/gen.h, editing it recompiles,
# and the hidden generated file is not a prerequisite.

mkdir -p src include

cat >Configfile <<EOF
LANGUAGES += c
GENERATE  += gen.h
BINARIES  += app
SOURCES   += app.c
EOF

cat >src/gen.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--generate) echo "#define V 1" ;;
esac
EOF
chmod +x src/gen.h.proc

echo "#define V 5" > include/gen.h

cat >src/app.c <<'EOF'
#include "gen.h"
#include <stdio.h>
int main(void) { printf("%d\n", V); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
grep "^obj/src/app.c/.*: " Makefile | grep -q "include/gen.h"
if grep "^obj/src/app.c/.*: " Makefile | grep -q "obj/proc/gen.h"
then
    exit 1
fi
make $MAKE_ARGS
test "$(./bin/app)" = "5"

sleep 2
echo "#define V 6" > include/gen.h
make $MAKE_ARGS
test "$(./bin/app)" = "6"

exit 0
