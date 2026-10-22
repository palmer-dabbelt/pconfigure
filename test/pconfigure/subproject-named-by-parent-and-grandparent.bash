#include "harness_start.bash"

# "a/b" is asked for twice: once by "a", which owns it, and once by
# the top, which wants it directly too.  It is read once, by whichever
# line comes first -- so in one order it is the top's child and in the
# other it is a's -- and either way the build from the top has to come
# out the same: everything linked in dependency order, b's tests run
# exactly once by the aggregate "make check", and "a" still buildable
# on its own afterwards.
setup() {
    rm -rf case
    mkdir -p case/src case/a/src case/a/b/src case/a/b/test/smoke

    cat >case/a/Configfile <<EOF
SUBPROJECTS += b

LANGUAGES   += c
LIBRARIES   += liba.so
LINKOPTS    += -Lb/lib
LINKOPTS    += -lb
SOURCES     += a.c
EOF

    cat >case/a/b/Configfile <<EOF
LANGUAGES   += c
LANGUAGES   += bash
LIBRARIES   += libb.so
SOURCES     += b.c

PHONY       += smoke
TESTSRC     += runs.bash
EOF

    echo 'int b(void) { return 41; }' > case/a/b/src/b.c
    echo 'int b(void); int a(void) { return b() + 1; }' > case/a/src/a.c
    cat >case/src/top.c <<EOF
#include <stdio.h>
int a(void);
int main(void) { printf("%d\n", a()); return 0; }
EOF
    echo 'echo ran >> "$PTEST_SRCDIR/../../runs"' > case/a/b/test/smoke/runs.bash
}

check_case() {
    (cd case && $PTEST_BINARY $PCONFIGURE_ARGS)
    (cd case && make $MAKE_ARGS)
    test "$(cd case && ./bin/top)" = "42"

    # Exactly one include of b's Makefile anywhere in the run, whoever
    # ended up owning it.
    test "$(cat case/Makefile case/a/obj/Makefile.a \
            | grep -c '^include .*Makefile.a.b$')" = "1"

    (cd case && make $MAKE_ARGS check)
    test "$(cat case/runs)" = "ran"
    test "$(tar -xOf case/a/b/check/smoke/runs.bash ptest__return)" = "0"
}

# The top asks for "a/b" before "a" does.
setup
cat >case/Configfile <<EOF
SUBPROJECTS += a/b
SUBPROJECTS += a

LANGUAGES   += c
BINARIES    += top
LINKOPTS    += -La/lib
LINKOPTS    += -la
SOURCES     += top.c
EOF
check_case

# And after.
setup
cat >case/Configfile <<EOF
SUBPROJECTS += a
SUBPROJECTS += a/b

LANGUAGES   += c
BINARIES    += top
LINKOPTS    += -La/lib
LINKOPTS    += -la
SOURCES     += top.c
EOF
check_case

exit 0
