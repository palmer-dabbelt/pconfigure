#include "harness_start.bash"

# LINKOPTS are hashed into the directory a program is linked in, so a
# new set of them is a new link rather than one make thinks is done.
# Going back to an earlier set names the earlier directory, whose link
# is still there and still newer than every object it was made from,
# and bin/app was copied from it only when it was newer than bin/app --
# which the in-between link made, so it never was.  The copy now has a
# record of which directory it copies from, and the revert rewrites
# it.
#
# The symbol's value is the observable: --defsym sets it at link time
# only.  Its low bits survive the load address a PIE is given.

mkdir -p src

cat >src/main.c <<'EOS'
#include <stdio.h>
extern char VALSYM[];
int main(void) { printf("%ld\n", (long)VALSYM & 0xfff); return 0; }
EOS

configure_with() {
    cat >Configfile <<EOC
LANGUAGES   += c
BINARIES    += app
LINKOPTS    += -Wl,--defsym=VALSYM=$1
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
