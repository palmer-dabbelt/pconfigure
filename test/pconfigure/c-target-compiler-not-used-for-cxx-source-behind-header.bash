#include "harness_start.bash"

# A C program whose header is implemented in C++: the manual says the
# .c++ behind the header is compiled as C++, "with C++'s compiler".
# The target's own COMPILER line names a C compiler, and a COMPILER is
# something said to the language that builds the target -- the C++
# file found behind the header has to be handed to C++'s compiler
# instead, or it is compiled as C and the static_cast below is a
# syntax error.  The gx.c behind util.c++'s own header is back in the
# target's language, though, and is still built with the target's
# COMPILER.

mkdir -p src

cat >Configfile <<'CONFIGFILE'
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
cat Makefile

# main.c and gx.c are compiled by the target's compiler, util.c++ by
# C++'s.
grep -q '^	@cc -x c .* -c src/main\.c ' Makefile
grep -q '^	@cc -x c .* -c src/gx\.c ' Makefile
grep -q ' -c src/util\.c++ ' Makefile
if grep -q '^	@cc -x c .* -c src/util\.c++ ' Makefile
then
    exit 1
fi

make $MAKE_ARGS
test "$(./bin/app)" = "3"

# gx.c is behind a header util.c++ reads, which puts it back in the
# target's language, and the target's COMPILER is the one for it: its
# object is named by the same compiler and options as main.c's.
objects() {
    find "obj/src/$1" -name '*.o' -printf '%f\n'
}
test "$(objects gx.c)" = "$(objects main.c)"
