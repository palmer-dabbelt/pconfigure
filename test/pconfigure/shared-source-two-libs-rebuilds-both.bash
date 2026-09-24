#include "harness_start.bash"

# One source feeding two LIBRARIES is the closest pconfigure comes to
# an object library (taxonomy type 5): there is no directive that
# produces a bare object collection, but a source listed under two
# libraries compiles once and is linked into both -- the pdeps comment
# that names "two targets built from the same sources with the same
# options" as the shared-object case.
#
# The correct incremental behavior is one compile, both archives
# relinked, the consumer relinked, and nothing compiled twice.  The
# failure shapes this test distinguishes: a missing rebuild (one of
# the two archives stale against the new source) and a spurious
# recompile (the same source run through the compiler twice in one
# build, once per library).

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

BINARIES  += app
DEPLIBS   += a
DEPLIBS   += b
SOURCES   += main.c

LIBRARIES += liba.a
SOURCES   += shared.c
SOURCES   += a.c

LIBRARIES += libb.a
SOURCES   += shared.c
SOURCES   += b.c
EOF

cat >src/shared.c <<'EOF'
int shared(void) { return 5; }
EOF

cat >src/a.c <<'EOF'
int a(void) { return 3; }
EOF

cat >src/b.c <<'EOF'
int b(void) { return 4; }
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
int shared(void);
int a(void);
int b(void);
int main(void) { printf("%d\n", shared() + a() + b()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS > first.out 2>&1
cat first.out
test "$(./bin/app)" = "12"

# A build that has nothing to do is the ordinary answer from here on,
# which is what makes the build after the edit mean something.
make $MAKE_ARGS > settled.out 2>&1
cat settled.out
grep -q "Nothing to be done" settled.out

##############################################################################
# The shared source changes                                                  #
##############################################################################
sleep 2
printf 'int shared(void) { return 15; }\n' > src/shared.c

make $MAKE_ARGS > second.out 2>&1
cat second.out

# Exactly one compile of the shared source -- the line appears once in
# the log, not once per library.
test "$(grep -c "^CC	shared.c$" second.out)" -eq 1

# Both libraries were rebuilt from it, and the consumer relinked.
grep -q "^LD	liba.a$" second.out
grep -q "^LD	libb.a$" second.out
grep -q "^LD	app$" second.out

# The per-library sources did not recompile -- nothing they own
# changed.
if grep -qE "^CC	(a|b)\.c$" second.out
then
    exit 1
fi

# The answer the binary gives is the new shared source's answer.
test "$(./bin/app)" = "22"

exit 0
