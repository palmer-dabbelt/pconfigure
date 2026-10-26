#include "harness_start.bash"

# A shared library is linked in a directory named by its options the
# same way a program is, so it had the same hole: an option put back
# to what an earlier build used named that build's link, which is
# older than the lib/libv.so the in-between build copied into place,
# and lib/libv.so -- which every program using it loads at run time --
# was left as it was.  The program needn't relink for this to show; it
# runs whatever library is on disk.  This makes sure the revert puts
# the right library back.

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

LIBRARIES   += libv.so
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
