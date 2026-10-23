#include "harness_start.bash"

# A COMPILEOPTS is a command line, and the manual's own ppkg-config
# example puts everything pkg-config says on one: an include path and
# a -DHAVE_TALLOC, side by side in a single line.  The compiler gets
# it split into words by the shell, so "-Wall -DWANT_EXTRA" defines
# WANT_EXTRA and the #ifdef that includes extra.h is taken.  The search
# for the sources behind a header has to read the line the same way,
# or it walks the other branch, never sees extra.h, and leaves extra.c
# out of the link while main.c goes on calling it.
#
# AUTORECONFIGURE = true, which is what decides who reads the options:
# pconfigure does under false and pdeps does under true, and the two
# have to agree with each other as well as with the compiler.

mkdir -p src

cat >Configfile <<EOC
AUTORECONFIGURE = true

LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -Wall -DWANT_EXTRA
SOURCES     += main.c
EOC

cat >src/extra.h <<'EOC'
int extra(void);
EOC

cat >src/extra.c <<'EOC'
#include "extra.h"
int extra(void) { return 7; }
EOC

cat >src/main.c <<'EOC'
#include <stdio.h>
#ifdef WANT_EXTRA
#include "extra.h"
#endif
int main(void)
{
#ifdef WANT_EXTRA
    printf("%d\n", extra());
#else
    printf("none\n");
#endif
    return 0;
}
EOC

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "7"
