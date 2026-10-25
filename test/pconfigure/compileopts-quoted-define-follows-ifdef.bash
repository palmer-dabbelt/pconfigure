#include "harness_start.bash"

# A COMPILEOPTS is read as the words the shell will split it into, and
# the shell takes quotes off a word as it splits: -D"WANT_EXTRA" is
# the same -DWANT_EXTRA to the compiler, and the #ifdef that includes
# extra.h is taken.  The search for the sources behind a header has to
# read the line the same way, or it sees a macro called "WANT_EXTRA"
# with the quotes still on, walks the other branch, and leaves extra.c
# out of a link where main.c goes on calling it.
#
# Both settings of AUTORECONFIGURE, since pconfigure reads the options
# under one and pdeps under the other.

for auto in false true
do
    rm -rf $auto
    mkdir -p $auto/src
    cd $auto

    cat >Configfile <<EOC
AUTORECONFIGURE = $auto
LANGUAGES   += c
COMPILEOPTS += -D"WANT_EXTRA"
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
    cd ..
done
