#include "harness_start.bash"

# A TESTSRC written in C is linked into a program that is only ever
# run out of the build tree, so the one link it needs is the local
# one.  The test was put together from everything a BINARIES gets and
# then had the installing targets filtered back out -- but only the
# copy into $(DESTDIR) said it was installing, so the install-flavoured
# link it copies from, the one with the PREFIX's rpath, stayed a
# prerequisite of the check and every "make check" linked each C test
# twice, once into a file nothing ever reads.

mkdir -p src test/hello

cat >Configfile <<'EOF'
LANGUAGES += c

BINARIES  += hello
SOURCES   += hello.c
TESTSRC   += runs.c
EOF

cat >src/hello.c <<'EOF'
int main(void) { return 0; }
EOF

cat >test/hello/runs.c <<'EOF'
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
make $MAKE_ARGS check > check.out
cat check.out

test "$(grep -c "^LD	runs.c$" check.out)" = 1

# And the install link isn't merely left off the check's prerequisites:
# a test is never installed, so the Makefile has no rule for one and
# nothing was linked into where it would have gone.
if grep -E '^[^:]*/check/hello/runs\.c/[^:]*/install:' Makefile
then
    exit 1
fi
if find obj -path '*/check/hello/runs.c/*/install' | grep -q .
then
    exit 1
fi

exit 0
