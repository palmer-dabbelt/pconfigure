#include "harness_start.bash"

# The compiled-test half of check-in-project-path-with-space.bash.
# The "--srcdir $(abspath ...)" a check recipe hands ptest is written
# once in languages/bash.c++ and once in languages/cxx.c++, so a
# quote added to one is a quote missing from the other until a test
# goes through both.
mkdir -p "my proj/src" "my proj/test/main"
cd "my proj"

echo 'int main(void) { return 0; }' > src/main.c
echo 'int main(void) { return 0; }' > test/main/t.c

cat >Configfile <<EOF
LANGUAGES += c

BINARIES  += main
SOURCES   += main.c
TESTSRC   += t.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS check

test "$(tar -xOf check/main/t.c ptest__return)" = 0
