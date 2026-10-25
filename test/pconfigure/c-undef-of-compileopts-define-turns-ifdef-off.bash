#include "harness_start.bash"

# An "#undef" takes away a name whichever way it was defined, and one
# given as a "-D" in COMPILEOPTS is no different from one a "#define"
# made: the compiler never sees the include below, so extra.c is never
# a source of this program.  The scan starts from the "-D" names and
# has to take this one back out at the "#undef", or it builds extra.c,
# which here refuses to compile.

mkdir -p src

cat >Configfile <<'EOC'
LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -DWITH_EXTRA
SOURCES     += main.c
EOC

cat >src/extra.h <<'EOC'
int extra(void);
EOC

cat >src/extra.c <<'EOC'
#error "extra.c is only built WITH_EXTRA"
EOC

cat >src/main.c <<'EOC'
#include <stdio.h>
#undef WITH_EXTRA
#ifdef WITH_EXTRA
#include "extra.h"
#endif
int main(void) { printf("app\n"); return 0; }
EOC

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

if grep -q "src/extra\.[ch]" Makefile
then
    exit 1
fi

make $MAKE_ARGS
test "$(./bin/app)" = "app"
