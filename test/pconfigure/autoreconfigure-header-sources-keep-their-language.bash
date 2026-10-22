#include "harness_start.bash"
#pconfigure TESTDEPS += bin/pdeps

# A source found behind a header is compiled as whatever its own name
# says it is, not as whatever the target that found it is written in
# -- and AUTORECONFIGURE, which moves that walk out of pconfigure and
# into pdeps, has to come to the same answer.  pdeps is handed one
# compiler per target, so without being told otherwise it compiles
# every source it finds with that one.
#
# The walk here crosses the line twice, C to C++ and back to C, and
# each step is a file only its own language accepts: a template and a
# reference in the C++, an implicit conversion from "void *" in the
# second C file.  A walk that keeps the language it started with
# fails on the first; one that keeps the language of whichever file
# it last passed through fails on the second.
#
# Configured both ways, because the same project has to build the
# same objects whichever of the two is doing the walking.

project() {
    mkdir -p "$1/src"
    (
        cd "$1"
        {
            test "$2" = "on" && echo "AUTORECONFIGURE = true"
            cat <<'CONFIGFILE'
LANGUAGES += c
LANGUAGES += c++

BINARIES  += app
SOURCES   += main.c
CONFIGFILE
        } > Configfile

        cat >src/fx.h <<'SOURCE'
#ifdef __cplusplus
extern "C"
#endif
int fx(void);
SOURCE

        cat >src/fx.c++ <<'SOURCE'
#include "fx.h"
#include "gx.h"
template<typename T> static T twice(const T& x) { return x + x; }
int fx(void) { int n = gx(); int& r = n; return twice(r); }
SOURCE

        cat >src/gx.h <<'SOURCE'
#ifdef __cplusplus
extern "C"
#endif
int gx(void);
SOURCE

        cat >src/gx.c <<'SOURCE'
#include <stdlib.h>
#include "gx.h"
int gx(void)
{
    int *p = malloc(sizeof(*p));
    int r;
    *p = 2;
    r = *p;
    free(p);
    return r;
}
SOURCE

        cat >src/main.c <<'SOURCE'
#include <stdio.h>
#include "fx.h"
int main(void) { printf("%d\n", fx()); return 0; }
SOURCE

        $PTEST_BINARY $PCONFIGURE_ARGS
        make $MAKE_ARGS
        test "$(./bin/app)" = "4"
    )
}

project off off
project on on

# The same objects either way: each source compiled once, by its own
# language, under the name that language's options hash to.
objects() {
    (cd "$1" && find obj/src -name '*.o' | sort)
}

objects off
objects on
test "$(objects off)" = "$(objects on)"
test "$(objects on | grep -c '^obj/src/fx\.c++/')" = 1
test "$(objects on | grep -c '^obj/src/gx\.c/')" = 1
