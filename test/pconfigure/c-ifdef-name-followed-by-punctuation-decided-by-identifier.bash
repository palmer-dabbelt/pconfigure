#include "harness_start.bash"

# The compiler reads "#ifdef VERBOSE(x)", "#ifdef VERBOSE;" and
# "#ifdef VERBOSE,LOGGING" as questions about VERBOSE, warning about
# what comes after it: the name is an identifier, and it ends where the
# identifier does, whether or not a space follows.  Cutting the line at
# the first space instead asks about "VERBOSE(x)", which nothing
# defines, and the scan then follows the branch the compiler skips
# without saying anything about it.
#
# VERBOSE is defined, so each "#ifdef" is taken and the "#ifndef" isn't.
# The taken branches are what bring the sources the link needs into
# the build, and the skipped one holds a header whose source can't be
# compiled, so a conditional decided on the wrong name fails the build
# one way or the other.

mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -DVERBOSE
SOURCES     += main.c
EOF2

cat >src/quiet.h <<'EOF2'
int quiet(void);
EOF2

cat >src/quiet.c <<'EOF2'
#error "quiet.c is only meant to be built without VERBOSE"
EOF2

for n in one two three
do
    cat >src/$n.h <<EOF2
int $n(void);
EOF2
    cat >src/$n.c <<EOF2
#include "$n.h"
int $n(void) { return 1; }
EOF2
done

cat >src/main.c <<'EOF2'
#include <stdio.h>
#ifdef VERBOSE(x)
#include "one.h"
#endif
#ifdef VERBOSE;
#include "two.h"
#endif
#ifdef VERBOSE,LOGGING
#include "three.h"
#endif
#ifndef VERBOSE;
#include "quiet.h"
#endif
int main(void) { printf("%d\n", one() + two() + three()); return 0; }
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

if grep -q "src/quiet\.[ch]" Makefile
then
    exit 1
fi

make $MAKE_ARGS
test "$(./bin/app)" = "3"
