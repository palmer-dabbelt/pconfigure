#include "harness_start.bash"

# A quote can open before the "-D" as well as after it: '-DWANT_EXTRA'
# is the same -DWANT_EXTRA to the compiler, and it is the natural way
# to write a define with parentheses or spaces in it.  The header scan
# matched the flag against the word as written, which starts with a
# quote, so the define was passed over, the #ifdef that includes
# extra.h looked off, and extra.c was left out of a link where main.c
# goes on calling it.
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
COMPILEOPTS += '-DWANT_EXTRA'
BINARIES    += app
SOURCES     += main.c
EOC

    echo 'int extra(void);' >src/extra.h
    echo 'int extra(void) { return 7; }' >src/extra.c

    cat >src/main.c <<'EOC'
#include <stdio.h>
#ifdef WANT_EXTRA
#include "extra.h"
#endif
int main(void) { printf("%d\n", extra()); return 0; }
EOC

    $PTEST_BINARY $PCONFIGURE_ARGS
    make $MAKE_ARGS
    test "$(./bin/app)" = "7"
    cd ..
done
