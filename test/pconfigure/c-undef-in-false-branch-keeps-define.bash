#include "harness_start.bash"

# An "#undef" in a branch that isn't taken undefines nothing, any more
# than an "#include" there includes anything.  The name below is still
# defined when the "#ifdef" asks about it, so the compiler sees
# extra.h and main() calls extra() -- and the scan has to follow the
# same include, or extra.c is left out of the link and the program
# fails on an undefined reference.

mkdir -p src

cat >Configfile <<'EOC'
LANGUAGES   += c

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
#define WITH_EXTRA
#ifdef NOT_DEFINED_ANYWHERE
#undef WITH_EXTRA
#endif
#ifdef WITH_EXTRA
#include "extra.h"
#endif
int main(void)
{
#ifdef WITH_EXTRA
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
