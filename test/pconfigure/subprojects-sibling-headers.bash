#include "harness_start.bash"

mkdir -p a/src b/src c/src

# "a" compiles against a header that "b" owns, which is what a project
# that keeps its pieces in sibling directories does.  The include path
# is written the way "a" sees it, since that is all "a" knows.
cat >Configfile <<EOF
SUBPROJECTS += a
SUBPROJECTS += b
SUBPROJECTS += c
EOF

cat >a/Configfile <<EOF
LANGUAGES   += c

BINARIES    += test
COMPILEOPTS += -I../b/src
SOURCES     += test.c
EOF

cat >b/Configfile <<EOF
LANGUAGES += c

LIBRARIES += libb.so
SOURCES   += b.c
EOF

# A third project, so that the sibling being named is not simply the
# only other thing in the run.
cat >c/Configfile <<EOF
LANGUAGES += c

LIBRARIES += libc.so
SOURCES   += c.c
EOF

cat >b/src/b.h <<EOF
#define B_ANSWER 42
EOF

cat >b/src/b.c <<EOF
int b(void) { return 0; }
EOF

cat >c/src/c.c <<EOF
int c(void) { return 0; }
EOF

cat >a/src/test.c <<EOF
  #include <stdio.h>
  #include "b.h"
int main(void) { printf("%d\n", B_ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
cat a/Makefile

# The header is a prerequisite of the object, and it belongs to "b" --
# so it gets named through "b"'s variable rather than written down the
# way it looks from the top.  A bare "b/src/b.h" in here is a path
# that only means anything when make was run above this project.
grep -q "^\$(pconfigure_subdir_a)obj/src/test.c/.*\.o: .*\$(pconfigure_subdir_b)src/b.h\$" a/Makefile

# ... and "a" says where "b" is when make was run in "a".
grep -q "^pconfigure_subdir_b ?= ../b/$" a/Makefile

# The top says it too, and says it first, so the answer everybody uses
# is the one belonging to wherever make was actually started.
grep -q "^pconfigure_subdir_b ?= b/$" Makefile

# Nothing pulls in a sibling's rules: "a" still has no idea how to
# build anything of "b"'s.
if grep -q "^include.*pconfigure_subdir_b" a/Makefile
then
    exit 1
fi

# Every variable is declared before the first include, or a
# subproject's own guess at where its siblings are would get in first
# and win.
first_include="$(grep -n "^include" Makefile | head -n1 | cut -d: -f1)"
last_variable="$(grep -n "^pconfigure_subdir" Makefile | tail -n1 | cut -d: -f1)"
test "$last_variable" -lt "$first_include"

make $MAKE_ARGS
test "$(./a/bin/test)" = "42"

# Now the whole point: "a" builds on its own.  What it needs from "b"
# is a file that is already there, and from down here it is one
# directory up and back down rather than next to the top.
cd a
rm -rf obj bin
make $MAKE_ARGS
test "$(./bin/test)" = "42"
cd ..

# The dependency is a real one, rather than a path that happens to
# exist: changing the header rebuilds, from either place.
sleep 2
cat >b/src/b.h <<EOF
#define B_ANSWER 7
EOF

make $MAKE_ARGS
test "$(./a/bin/test)" = "7"

exit 0
