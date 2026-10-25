#include "harness_start.bash"

# SRCDIR is a directory, and "code", "code/", "./code" and "code//" are
# four spellings of the one directory.  Each has to build, and each has
# to link the source behind a header exactly once even when the
# Configfile also names that source -- the header scan reaches it
# through its own spelling of the path, and two spellings of one file
# would be two objects defining the same function.

mkdir -p code

cat >code/main.c <<'EOC'
#include "x.h"
int main(void) { return x(); }
EOC

echo 'int x(void);' > code/x.h

cat >code/x.c <<'EOC'
#include "x.h"
int x(void) { return 0; }
EOC

for dir in code code/ ./code code//
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

    # One object for x.c on the link line, however it was reached.
    test "$(grep -- '-oobj/bin/main/[0-9]*/local ' Makefile | tr ' ' '\n' | grep -c 'x\.c/')" = 1
done
