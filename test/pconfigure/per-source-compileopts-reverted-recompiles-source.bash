#include "harness_start.bash"

# A COMPILEOPTS under a SOURCES belongs to that one source, and its
# object is hashed by it the same way a target-wide option's is.  So
# the revert that goes back to an option an earlier build used found
# that build's object still in place, and the binary linked from the
# in-between object was never relinked: only one of the two sources
# changed options, and neither of them was newer than the program.
# This makes sure a revert of one source's options relinks.

mkdir -p src

cat >src/main.c <<'EOS'
#include <stdio.h>
int val(void);
int main(void) { printf("%d\n", val()); return 0; }
EOS

cat >src/val.c <<'EOS'
int val(void) { return VAL; }
EOS

configure_with() {
    cat >Configfile <<EOC
LANGUAGES   += c
BINARIES    += app
SOURCES     += main.c
SOURCES     += val.c
COMPILEOPTS += -DVAL=$1
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
