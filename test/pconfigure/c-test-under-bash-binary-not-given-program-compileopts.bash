#include "harness_start.bash"

# The tests of a BASH binary are reached from languages/bash.c++ rather
# than from languages/cxx.c++, and a test there written in C is handed
# on with the program's options dropped just the same -- so it has to
# drop them from the test's source as well, which is where the C
# compile line reads them from.  "-D NAME=value" means something to
# pbashc and to the C compiler both, which is what makes it easy to
# see here: the script's GREETING must not turn up in the C test,
# while the TESTING written under the TESTSRC must.

mkdir -p src test/tool

cat >Configfile <<'EOF'
LANGUAGES   += bash
LANGUAGES   += c

BINARIES    += tool
COMPILEOPTS += -D GREETING=hello
SOURCES     += tool.bash
TESTSRC     += t.c
COMPILEOPTS += -DTESTING
EOF

cat >src/tool.bash <<'EOF'
echo GREETING
EOF

cat >test/tool/t.c <<'EOF'
#ifndef TESTING
#error "the test's own option is missing"
#endif
#ifdef GREETING
#error "the BASH program's option reached the C test"
#endif
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

make $MAKE_ARGS
test "$(./bin/tool)" = "hello"
make $MAKE_ARGS check
test "$(tar -xOf check/tool/t.c ptest__return)" = "0"
