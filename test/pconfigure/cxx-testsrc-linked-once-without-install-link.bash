#include "harness_start.bash"

# The C++ spelling of a compiled test, which goes through the same rule
# as a C one: one link of the test program, the one it is run from, and
# not a second, install-flavoured link that nothing runs.

mkdir -p src test/hello

cat >Configfile <<'EOF'
LANGUAGES += c++

BINARIES  += hello
SOURCES   += hello.c++
TESTSRC   += runs.c++
EOF

cat >src/hello.c++ <<'EOF'
int main() { return 0; }
EOF

cat >test/hello/runs.c++ <<'EOF'
int main() { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
make $MAKE_ARGS check > check.out
cat check.out

test "$(grep -c "^LD++	runs.c++$" check.out)" = 1

if grep -E '^[^:]*/check/hello/runs\.c\+\+/[^:]*/install:' Makefile
then
    exit 1
fi

exit 0
