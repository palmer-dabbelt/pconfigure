#include "harness_start.bash"

# "-DNAME(args)" with no '=' defines a function-like NAME whose body
# is 1.  The header scan used to keep "NAME(args)" whole as the name,
# so an "#ifdef NAME" in the source was a question about a name it
# thought nobody defined: it skipped the branch the compiler takes,
# the header there led nowhere, and extra.c never reached the link
# that main.c's call to extra() needs.
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
COMPILEOPTS += -DHAVE_EXTRA\(x\)
BINARIES    += app
SOURCES     += main.c
EOC

    echo 'int extra(void);' >src/extra.h
    echo 'int extra(void) { return 8; }' >src/extra.c

    cat >src/main.c <<'EOC'
#include <stdio.h>
#ifdef HAVE_EXTRA
#include "extra.h"
#endif
int main(void) { printf("%d\n", extra()); return 0; }
EOC

    $PTEST_BINARY $PCONFIGURE_ARGS
    make $MAKE_ARGS
    test "$(./bin/app)" = "8"
    cd ..
done
