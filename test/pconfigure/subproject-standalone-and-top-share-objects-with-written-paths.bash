#include "harness_start.bash"

# A subproject configured from the top and configured on its own share
# what they build, which takes the object and link hashes agreeing
# about every path pconfigure roots at the subproject.  Those hashes
# respell only the paths pconfigure rooted, and the rooting is done in
# several places: "-I" stuck on, "-isystem" as a word of its own, a
# forced include that is there in the subproject's directory, and a
# "-L" in LINKOPTS, which the link line roots but the link's hash takes
# as written.  A '-D' whose value starts with the subproject's name is
# here too, since that is the one word that must come through as
# written on both sides.  Any of these spelled differently by the two
# runs would have the second make build everything over again.
mkdir -p sub/src sub/include sub/sys sub/pre

cat >Configfile <<'EOF2'
SUBPROJECTS += sub
EOF2

cat >sub/Configfile <<'EOF2'
LANGUAGES   += c
COMPILEOPTS += -Iinclude
COMPILEOPTS += -isystem sys
COMPILEOPTS += -include forced.h
COMPILEOPTS += -DWHERE='"sub/marine"'
LINKOPTS    += -Lpre
LINKOPTS    += -lvalue

BINARIES    += tool
SOURCES     += tool.c
EOF2

echo '#define FORCED 1' > sub/forced.h
echo 'int value(void);' > sub/include/value.h
echo '#define SYS 0' > sub/sys/sys.h
echo 'int value(void) { return 0; }' > sub/pre/value.c
${CC:-cc} -c sub/pre/value.c -o sub/pre/value.o
${AR:-ar} rcs sub/pre/libvalue.a sub/pre/value.o
cat >sub/src/tool.c <<'EOF2'
#include <string.h>
#include <sys.h>
#include "value.h"
int main(void) { return value() + SYS + !FORCED + strcmp(WHERE, "sub/marine"); }
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
(cd sub && $PTEST_BINARY $PCONFIGURE_ARGS)

make $MAKE_ARGS
./sub/bin/tool

(cd sub && make $MAKE_ARGS) > inside.out 2>&1
cat inside.out
if grep -q "^CC	\|^LD	\|^CP	" inside.out
then
    exit 1
fi

test "$(ls sub/obj/src/tool.c | grep -c '\.o$')" = "1"
