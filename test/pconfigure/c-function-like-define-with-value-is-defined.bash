#include "harness_start.bash"

# "-DNAME(args)=body" defines the function-like macro NAME; the
# parenthesised parameter list is part of the definition, not of the
# name.  The header scan used to take everything up to the '=' as the
# name, so it asked "#ifndef LOG" about a macro called "LOG(x)" that
# nothing tests, decided LOG was undefined, and followed the fallback
# branch into a header the compiler skips.  The source behind that
# header doesn't compile, so linking it in fails the build.
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
COMPILEOPTS += '-DLOG(x)=(x)'
BINARIES    += app
SOURCES     += main.c
EOC

    echo 'int LOG(int);' >src/fallback.h
    echo '#error "LOG is defined on the command line, so nothing reads fallback.h"' >src/fallback.c

    cat >src/main.c <<'EOC'
#include <stdio.h>
#ifndef LOG
#include "fallback.h"
#endif
int main(void) { printf("%d\n", LOG(7)); return 0; }
EOC

    $PTEST_BINARY $PCONFIGURE_ARGS
    make $MAKE_ARGS
    test "$(./bin/app)" = "7"
    cd ..
done
