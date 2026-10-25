#include "harness_start.bash"

# "-D 'WANT_EXTRA'" is the spelling with the name as a word of its own,
# quoted the way a generator that quotes every argument it prints
# writes it.  The shell hands the compiler "-D" and "WANT_EXTRA", so the
# #ifdef is taken and main.c calls extra(); the header scan has to name
# the same macro, quotes off, or extra.c never reaches the link.

mkdir -p src

cat >Configfile <<'EOC'
LANGUAGES   += c
COMPILEOPTS += -D 'WANT_EXTRA'
BINARIES    += app
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
make $MAKE_ARGS
test "$(./bin/app)" = "7"
