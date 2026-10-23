#include "harness_start.bash"

# The other direction from
# c-binary-cxx-source-behind-header-compiled-as-cxx.bash, and not its
# mirror image.  C can't compile C++, so a ".c++" behind a C program's
# header has to go to C++.  C++ can compile C, and a C++ target keeps
# the ".c" it finds behind its own headers: that is how one C source
# is built twice, once as a C library and once as a C++ one whose
# header puts the same functions in a namespace.  gitdate.bash and
# multi-language-build.bash both build that way, and handing the ".c"
# to C instead leaves the C++ side with a mangled name nothing defines.
#
# So the one fx.c is compiled both ways here, once for each program,
# and each program links against the copy in its own language.

mkdir -p src

cat >Configfile <<'CONFIGFILE'
LANGUAGES += c
LANGUAGES += c++

BINARIES  += app
SOURCES   += main.c

BINARIES  += app++
SOURCES   += main.c++
CONFIGFILE

cat >src/fx.h <<'SOURCE'
#ifdef __cplusplus
namespace fx {
#endif
int fx(void);
#ifdef __cplusplus
}
#endif
SOURCE

cat >src/fx.c <<'SOURCE'
#include "fx.h"
#ifdef __cplusplus
namespace fx {
int fx(void) { return 2; }
}
#else
int fx(void) { return 1; }
#endif
SOURCE

cat >src/main.c <<'SOURCE'
#include <stdio.h>
#include "fx.h"
int main(void) { printf("%d\n", fx()); return 0; }
SOURCE

cat >src/main.c++ <<'SOURCE'
#include <cstdio>
#include "fx.h"
int main(void) { std::printf("%d\n", fx::fx()); return 0; }
SOURCE

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# Said outright as well as shown by the programs below, so a build
# that went wrong some other way can't pass for this one.
grep -- "-x c .*src/fx\.c " Makefile
grep -- "-x c++ .*src/fx\.c " Makefile

make $MAKE_ARGS
test "$(./bin/app)" = "1"
test "$(./bin/app++)" = "2"
