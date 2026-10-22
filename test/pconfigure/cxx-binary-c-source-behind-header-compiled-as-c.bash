#include "harness_start.bash"

# The other direction from
# c-binary-cxx-source-behind-header-compiled-as-cxx.bash.  The manual
# says C++ "supports linking against C", and a C file found behind a
# header a C++ source includes is still C: an implicit conversion from
# "void *" is ordinary C and an error in C++.  Compiling it with
# "-x c++" because the target that found it is a C++ one makes the
# file mean something it doesn't.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c
LANGUAGES += c++

BINARIES  += app
SOURCES   += main.c++
EOF

cat >src/fx.h <<'EOF'
#ifdef __cplusplus
extern "C"
#endif
int fx(void);
EOF

cat >src/fx.c <<'EOF'
#include <stdlib.h>
#include "fx.h"
int fx(void)
{
    int *p = malloc(sizeof(*p));
    int r;
    *p = 4;
    r = *p;
    free(p);
    return r;
}
EOF

cat >src/main.c++ <<'EOF'
#include <cstdio>
#include "fx.h"
int main(void) { std::printf("%d\n", fx()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# Said outright as well as shown by the build below working, for the
# same reason the other direction says it.
grep -- "-x c .*src/fx\.c " Makefile
if grep -- "-x c++ .*src/fx\.c " Makefile
then
    exit 1
fi

make $MAKE_ARGS
test "$(./bin/app)" = "4"
