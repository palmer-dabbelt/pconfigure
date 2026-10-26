#include "harness_start.bash"

# The places a header might turn up and shadow the one a source was
# built against are written into the source's fragment, which a
# subproject's Makefile reads from two places: from the top, and from
# inside the subproject.  Those places are paths like any other in
# there, so they have to be spelled through the subproject's variable
# -- spelled from the top alone, a build from inside would look for the
# shadowing header one directory too high and never find it, and
# spelled wrongly the other way it would find it every time and never
# settle.

mkdir -p sub/src sub/inc

cat >Configfile <<'EOC'
AUTORECONFIGURE = true
SUBPROJECTS    += sub
EOC

cat >sub/Configfile <<'EOC'
LANGUAGES   += c
BINARIES    += app
COMPILEOPTS += -Iinc
SOURCES     += main.c
EOC

echo '#define V 1' > sub/inc/x.h

cat >sub/src/main.c <<'EOS'
#include <stdio.h>
#include "x.h"
int main(void) { printf("%d\n", V); return 0; }
EOS

$PTEST_BINARY $PCONFIGURE_ARGS
timeout 60 make $MAKE_ARGS
test "$(./sub/bin/app)" = "1"

sleep 2
echo '#define V 2' > sub/src/x.h

(cd sub && timeout 60 make $MAKE_ARGS -f obj/Makefile.sub)
test "$(./sub/bin/app)" = "2"

(cd sub && timeout 60 make $MAKE_ARGS -f obj/Makefile.sub) > inside.out 2>&1
cat inside.out
grep -q "Nothing to be done" inside.out

timeout 60 make $MAKE_ARGS > top.out 2>&1
cat top.out
grep -q "Nothing to be done" top.out
