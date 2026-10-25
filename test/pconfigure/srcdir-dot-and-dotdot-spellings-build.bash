#include "harness_start.bash"

# SRCDIR's slash spellings are pinned elsewhere; these are the ones
# with dots in them.  "." is how a project with its sources at the top
# says so, "src/../code" and "./code/./" climb or wander but end inside
# the project.  Each has to build, and each has to link the source
# behind a header exactly once though the Configfile names it too,
# since the header scan reaches it through its own spelling.
mkdir -p code src
for dir in . code
do
    cat >$dir/main.c <<'EOC'
#include "x.h"
int main(void) { return x(); }
EOC
    echo 'int x(void);' > $dir/x.h
    cat >$dir/x.c <<'EOC'
#include "x.h"
int x(void) { return 0; }
EOC
done

for dir in . ./ src/../code ./code/./
do
    rm -rf Makefile obj bin
    cat >Configfile <<EOC
LANGUAGES   += c
SRCDIR       = $dir
BINARIES    += main
SOURCES     += main.c
SOURCES     += x.c
EOC

    $PTEST_BINARY $PCONFIGURE_ARGS
    make $MAKE_ARGS
    ./bin/main

    test "$(grep -- '-oobj/bin/main/[0-9]*/local ' Makefile | tr ' ' '\n' | grep -c 'x\.c/')" = 1
done
