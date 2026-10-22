#include "harness_start.bash"

# A C program whose header is implemented in C++: the header has the
# usual __cplusplus guard for exactly this, and the manual says the
# search for the source behind a header finds "foo.c++" next to
# "foo.h" just as it finds "foo.c".  What it finds has to be compiled
# as what it is.  Handing a ".c++" to the C compiler with "-x c" turns
# the first C++-only construct into a hard error -- c-cxx.bash only
# passes because its C++ file happens to also be valid C.
#
# The C++ here is all language and no library: a template and a
# reference, neither of which needs anything from the C++ runtime.
# What a C program is linked with is a different question from what
# its sources are compiled as, and this one is only asking the second.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c
LANGUAGES += c++

BINARIES  += app
SOURCES   += main.c
EOF

cat >src/fx.h <<'EOF'
#ifdef __cplusplus
extern "C"
#endif
int fx(void);
EOF

cat >src/fx.c++ <<'EOF'
#include "fx.h"
template<typename T> static T twice(const T& x) { return x + x; }
int fx(void) { int two = 2; int& r = two; return twice(r); }
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
#include "fx.h"
int main(void) { printf("%d\n", fx()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# Said outright as well as shown by the build below working, because
# a compiler that guesses the language from the file's name would
# paper over the wrong flag.
grep -- "-x c++ .*src/fx\.c++" Makefile
if grep -- "-x c .*src/fx\.c++" Makefile
then
    exit 1
fi

make $MAKE_ARGS
test "$(./bin/app)" = "4"
