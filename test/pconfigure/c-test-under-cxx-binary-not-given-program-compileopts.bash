#include "harness_start.bash"

# A test written in a different language from the program it tests
# is meant to leave the program's COMPILEOPTS behind, because they were
# said to the program's language: that is what keeps a C++-only flag
# off a BASH test, and context::without_clopts() is how it is done.  A
# compiled test only has its options cleared on the test's own
# context, though, and its source was copied from the program before
# that, so the C file is compiled with the C++ program's options
# anyway.  The options written under the TESTSRC itself were said to
# the test, in its own language, and those it does need: TESTING here
# is only defined by the line under the test.

mkdir -p src test/app

cat >Configfile <<'EOF'
LANGUAGES   += c++
LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -DPROGRAM_ONLY
SOURCES     += main.c++
TESTSRC     += t.c
COMPILEOPTS += -DTESTING
EOF

cat >src/main.c++ <<'EOF'
#ifndef PROGRAM_ONLY
#error "the program's own option is missing"
#endif
int main() { return 0; }
EOF

cat >test/app/t.c <<'EOF'
#ifndef TESTING
#error "the test's own option is missing"
#endif
#ifdef PROGRAM_ONLY
#error "the C++ program's option reached the C test"
#endif
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

make $MAKE_ARGS
make $MAKE_ARGS check
test "$(tar -xOf check/app/t.c ptest__return)" = "0"
