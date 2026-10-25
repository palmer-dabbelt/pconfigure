#include "harness_start.bash"

# '-includesrc/extra.h' is the shell's -includesrc/extra.h, quote and
# all, the same as -include'src/extra.h'.  The header scan matched
# "-include" against the word as written, which starts with a quote,
# so it never read the header the compiler is made to read first:
# extra.c, the source behind that header, was left out of the link
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
COMPILEOPTS += '-includesrc/extra.h'
BINARIES    += app
SOURCES     += main.c
EOC

    echo 'int extra(void);' >src/extra.h
    echo 'int extra(void) { return 6; }' >src/extra.c

    cat >src/main.c <<'EOC'
#include <stdio.h>
int main(void) { printf("%d\n", extra()); return 0; }
EOC

    $PTEST_BINARY $PCONFIGURE_ARGS
    make $MAKE_ARGS
    test "$(./bin/app)" = "6"
    cd ..
done
