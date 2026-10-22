#include "harness_start.bash"

# Which language compiles a source found behind a header is decided by
# the source's own name, and nothing else: in particular not by the
# order of the LANGUAGES lines.  SWIG is built on top of C++ and used
# to inherit C++'s list of what a C++ source is called, so declaring
# it before C++ handed a C program's ".c++" to pswigcc, with SWIG's
# options and SWIG's object name, while declaring it after gave plain
# C++.  SWIG's own sources are ".i" files; it has no claim on these.
#
# Nothing here is a SWIG library, so neither swig nor Python is needed:
# the Makefile saying which compiler gets the file is the whole answer.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c
LANGUAGES += swig
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

grep -- "-x c++ .*src/fx\.c++" Makefile
if grep -e "SWCC.*fx\.c++" -e "pswigcc.*fx\.c++" Makefile
then
    exit 1
fi

make $MAKE_ARGS
test "$(./bin/app)" = "4"
