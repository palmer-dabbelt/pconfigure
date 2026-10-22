#include "harness_start.bash"

# The same nested test directory as a C test rather than a bash one.
# A check target is written twice, once by languages/bash.c++ and once
# by languages/cxx.c++, and a fix to one that never reached the other
# is exactly what a bash-only test would miss.  A compiled test's
# tarball is check/main/nested/t.c, and the directory it goes in has
# to exist before ptest writes it.
mkdir -p src test/main/nested
echo 'int main(void) { return 0; }' > src/main.c
echo 'int main(void) { return 0; }' > test/main/nested/t.c

cat >Configfile <<EOF
LANGUAGES += c

BINARIES  += main
SOURCES   += main.c
TESTSRC   += nested/t.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS check

test -f check/main/nested/t.c
test "$(tar -xOf check/main/nested/t.c ptest__return)" = 0
