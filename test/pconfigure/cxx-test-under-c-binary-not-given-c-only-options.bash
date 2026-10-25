#include "harness_start.bash"

# The other way round from c-test-under-cxx-binary-not-given-program-
# compileopts.bash, with the options that make it matter: a C program
# built with "-std=c99 -Werror" and a test of it written in C++.  The
# program's options are C's, and are meant to be dropped for a test in
# another language, but the test's source still carries them: g++
# warns that "-std=c99" isn't a C++ option and "-Werror" makes the
# warning stop the build, so "make check" never gets to run the test.

mkdir -p src test/app

cat >Configfile <<'EOF'
LANGUAGES   += c
LANGUAGES   += c++

BINARIES    += app
COMPILEOPTS += -std=c99 -Werror
SOURCES     += main.c
TESTSRC     += t.c++
EOF

cat >src/main.c <<'EOF'
int main(void) { return 0; }
EOF

cat >test/app/t.c++ <<'EOF'
int main() { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

if grep -E '^	@.* -c test/app/t\.c\+\+ ' Makefile | grep -q -- '-std=c99'
then
    exit 1
fi

make $MAKE_ARGS
make $MAKE_ARGS check
test "$(tar -xOf check/app/t.c++ ptest__return)" = "0"
