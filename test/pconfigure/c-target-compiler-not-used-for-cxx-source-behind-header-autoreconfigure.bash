#include "harness_start.bash"
#pconfigure TESTDEPS += bin/pdeps

# The same C program with its header implemented in C++, with
# AUTORECONFIGURE moving the walk that finds util.c++ into pdeps.  pdeps
# compiles what it finds with whatever compiler the context file for
# that source's language names, and pconfigure writes that file -- so
# the C target's "COMPILER = cc -x c" has to stay out of C++'s one
# too, or pdeps hands the C++ file to the C compiler and the
# static_cast below stops the build.  The gx.c behind util.c++'s own
# header is C again, and is built with the target's COMPILER the same
# as main.c is.

mkdir -p src

cat >Configfile <<'CONFIGFILE'
AUTORECONFIGURE = true
LANGUAGES += c++
LANGUAGES += c

BINARIES  += app
COMPILER   = cc -x c
LINKOPTS  += -lstdc++
SOURCES   += main.c
CONFIGFILE

cat >src/util.h <<'SOURCE'
#ifdef __cplusplus
extern "C"
#endif
int util(void);
SOURCE

cat >src/util.c++ <<'SOURCE'
#include "util.h"
#include "gx.h"
extern "C" int util(void) { return static_cast<int>(gx() + 1); }
SOURCE

cat >src/gx.h <<'SOURCE'
#ifdef __cplusplus
extern "C"
#endif
int gx(void);
SOURCE

cat >src/gx.c <<'SOURCE'
#include "gx.h"
int gx(void) { return 2; }
SOURCE

cat >src/main.c <<'SOURCE'
#include <stdio.h>
#include "util.h"
int main(void) { printf("%d\n", util()); return 0; }
SOURCE

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "3"

# gx.c is behind a header util.c++ reads, which puts it back in the
# target's language, and the target's COMPILER is the one for it: its
# object is named by the same compiler and options as main.c's.
objects() {
    find "obj/src/$1" -name '*.o' -printf '%f\n'
}
test "$(objects gx.c)" = "$(objects main.c)"
