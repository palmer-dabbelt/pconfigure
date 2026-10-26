#include "harness_start.bash"

# make install copies the install-flavoured link, which is made in the
# same directory, named by the target's options, that the tree's copy
# comes from.  A COMPILEOPTS put back to an earlier build's value names
# the install link the first "make install" left there, which is up to
# date and older than the copy the build in between installed, so the
# installed program used to stay as the in-between build made it.
# This makes sure the revert reaches the installed copy.

mkdir -p src

cat >src/main.c <<'EOS'
#include <stdio.h>
int main(void) { printf("%d\n", VAL); return 0; }
EOS

configure_with() {
    cat >Configfile <<EOC
LANGUAGES   += c
PREFIX       = /usr
BINARIES    += app
COMPILEOPTS += -DVAL=$1
SOURCES     += main.c
EOC
    $PTEST_BINARY $PCONFIGURE_ARGS
}

configure_with 1
make $MAKE_ARGS install DESTDIR="$(pwd)/stage"
test "$(./stage/usr/bin/app)" = "1"

sleep 2
configure_with 2
make $MAKE_ARGS install DESTDIR="$(pwd)/stage"
test "$(./stage/usr/bin/app)" = "2"

sleep 2
configure_with 1
make $MAKE_ARGS install DESTDIR="$(pwd)/stage"
test "$(./stage/usr/bin/app)" = "1"
