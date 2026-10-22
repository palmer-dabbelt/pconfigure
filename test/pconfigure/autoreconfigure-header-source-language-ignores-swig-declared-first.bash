#include "harness_start.bash"
#pconfigure TESTDEPS += bin/pdeps

# header-source-language-ignores-swig-declared-first.bash, with pdeps
# doing the walk.  pdeps doesn't decide anything about languages
# itself: it switches to whichever context file pconfigure listed for
# a ".c++", so it gets SWIG's compiler exactly when pconfigure would
# have, and has to come to the same answer here as without
# AUTORECONFIGURE -- plain C++, whatever order LANGUAGES is in.

project() {
    mkdir -p "$1/src"
    (
        cd "$1"
        {
            test "$1" = "on" && echo "AUTORECONFIGURE = true"
            cat <<'CONFIGFILE'
LANGUAGES += c
LANGUAGES += swig
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
template<typename T> static T twice(const T& x) { return x + x; }
int fx(void) { int two = 2; int& r = two; return twice(r); }
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

project off
project on

# Neither the Makefile nor anything pdeps wrote for the walk below it
# hands the file to SWIG.
if grep -r -e "SWCC.*fx\.c++" -e "pswigcc" off/Makefile on/Makefile on/obj
then
    exit 1
fi

# And the object is the one C++ names, the same one both ways.
objects() {
    (cd "$1" && find obj/src -name '*.o' | sort)
}

objects off
objects on
test "$(objects off)" = "$(objects on)"
