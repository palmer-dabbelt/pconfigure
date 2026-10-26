#include "harness_start.bash"

# A static archive is put together in a directory named by its
# options, and the program linking it takes a copy of what it needs.
# Reverting the archive's option names the archive an earlier build
# left, which is older than the lib/libv.a the build in between copied
# into place, so the copy used to stay as it was -- and the program,
# which only relinks when that copy changes, kept the in-between code
# with it.  This makes sure both are redone.

mkdir -p src

cat >src/v.c <<'EOS'
int v(void) { return VAL; }
EOS

cat >src/main.c <<'EOS'
#include <stdio.h>
int v(void);
int main(void) { printf("%d\n", v()); return 0; }
EOS

configure_with() {
    cat >Configfile <<EOC
LANGUAGES   += c

LIBRARIES   += libv.a
COMPILEOPTS += -DVAL=$1
SOURCES     += v.c

BINARIES    += app
DEPLIBS     += v
SOURCES     += main.c
EOC
    $PTEST_BINARY $PCONFIGURE_ARGS
}

configure_with 1
make $MAKE_ARGS
test "$(./bin/app)" = "1"

sleep 2
configure_with 2
make $MAKE_ARGS
test "$(./bin/app)" = "2"

sleep 2
configure_with 1
make $MAKE_ARGS
test "$(./bin/app)" = "1"
