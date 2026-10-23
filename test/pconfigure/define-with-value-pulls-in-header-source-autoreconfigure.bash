#include "harness_start.bash"

# "-DNAME=value" defines NAME as surely as "-DNAME" does, and the
# compiler agrees: the #ifdef below is taken.  The search for the
# sources behind a header has to agree as well, or it walks the other
# branch of the #ifdef, never sees extra.h, and leaves extra.c out of
# the link -- an "undefined reference" for a program the compiler
# compiled correctly.
#
# AUTORECONFIGURE = true, which is what decides who reads the options:
# pconfigure does under false and pdeps does under true, and the two
# have to agree with each other as well as with the compiler.

mkdir -p src

cat >Configfile <<EOC
AUTORECONFIGURE = true

LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -DWANT_EXTRA=1
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
