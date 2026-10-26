#include "harness_start.bash"

# A target's COMPILEOPTS go on its link line as well as its compile
# lines, so they are hashed into the name of the directory it is
# linked in, and a COMPILEOPTS edit gives it a new link rather than a
# stale one.  The catch was the edit that goes back: putting -DVAL=1
# back after a build with -DVAL=2 names the directory the first build
# linked in, whose program is still there and up to date, and older
# than the bin/app the build in between copied out of the other one.
# The copy was only redone when its source was newer, so make kept the
# -DVAL=2 program while the Makefile said -DVAL=1.  This makes sure
# the revert copies the right link back.  Trying a flag and taking it
# back out is about the most ordinary edit a Configfile gets.

mkdir -p src

cat >src/main.c <<'EOS'
#include <stdio.h>
int main(void) { printf("%d\n", VAL); return 0; }
EOS

configure_with() {
    cat >Configfile <<EOC
LANGUAGES   += c
BINARIES    += app
COMPILEOPTS += -DVAL=$1
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

# Back to what the first build used.
sleep 2
configure_with 1
make $MAKE_ARGS
test "$(./bin/app)" = "1"
