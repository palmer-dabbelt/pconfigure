#include "harness_start.bash"

# A header found through a quoted -I is still a header the source was
# compiled against, so editing it has to rebuild the source.  The
# unquoted spelling is built first, as the control: the two lines say
# the same thing to the compiler, and they have to say the same thing
# to the dependency scan too.

for spelling in '-Isrc/lib' '-I"src/lib"'
do
    rm -rf obj bin Makefile
    mkdir -p src/lib

    cat >Configfile <<EOC
LANGUAGES   += c
COMPILEOPTS += $spelling
BINARIES    += app
SOURCES     += main.c
EOC

    echo '#define VALUE 1' > src/lib/value.h

    cat >src/main.c <<'EOC'
#include <stdio.h>
#include <value.h>
int main(void) { printf("%d\n", VALUE); return 0; }
EOC

    $PTEST_BINARY $PCONFIGURE_ARGS
    make $MAKE_ARGS
    test "$(./bin/app)" = "1"

    sleep 1
    echo '#define VALUE 2' > src/lib/value.h
    make $MAKE_ARGS
    test "$(./bin/app)" = "2"
done
