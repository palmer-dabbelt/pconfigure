#include "harness_start.bash"

# A subproject that compiles against a header a sibling owns, built
# from inside itself.
#
# This is where one fragment serving two builds did its worst damage.
# A fragment writes paths into its own project through the variable
# that names it, which means the same file from either place; paths
# into a *sibling* come out bare, and bare means "from the top of the
# tree".  Read from inside the subproject, "b/src/b.h" resolves to
# "a/b/src/b.h", which is not there.
#
# pdeps writes an empty rule for every header on purpose, so that a
# deleted header causes a rebuild rather than stopping the build --
# which meant make never reported the missing file.  It decided the
# fragment was out of date, re-ran pdeps, restarted to re-read it,
# decided it was out of date again, and did that until somebody
# stopped it.  Hundreds of DEPS lines in a quarter of a minute, no
# build, no error.
#
# There are two fragments now, each written by the run that reads it,
# so the sibling is named the way that run sees it: "b/src/b.h" from
# the top and "../b/src/b.h" from inside.  The question this asks is
# whether make finishes.
mkdir -p a/src b/src

cat >Configfile <<EOF
# The fragments this is about only exist under AUTORECONFIGURE, which
# is what moves "which headers does this source read" out of
# pconfigure and into make.
AUTORECONFIGURE = true

SUBPROJECTS += a
SUBPROJECTS += b
EOF

cat >a/Configfile <<EOF
AUTORECONFIGURE = true

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

cat >b/src/b.h <<EOF
#define B_ANSWER 42
EOF

cat >b/src/b.c <<EOF
int b(void) { return 0; }
EOF

cat >a/src/test.c <<EOF
#include <stdio.h>
#include "b.h"
int main(void) { printf("%d\n", B_ANSWER); return 0; }
EOF

##############################################################################
# From the top                                                               #
##############################################################################
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./a/bin/test)" = "42"

# The sibling's header, named from the top of the tree, which is where
# the build that wrote this one was standing.
test "$(ls a/obj/src/test.c/*.d | wc -l)" -eq 1
from_the_top="$(echo a/obj/src/test.c/*.d)"
grep -q "^b/src/b.h:\$" "$from_the_top"

##############################################################################
# ... and from inside                                                        #
##############################################################################
(cd a && $PTEST_BINARY $PCONFIGURE_ARGS)

# Bounded, because the failure this is about is not a failure: it is a
# make that never returns.  A test that waited for it would hang the
# suite rather than report anything.
(cd a && timeout 60 make $MAKE_ARGS > inside.out 2>&1) || {
    cat a/inside.out
    exit 1
}
cat a/inside.out

# It ran pdeps a handful of times and stopped, rather than restarting
# forever.  One per source is the honest number; the bound is loose
# because what is being ruled out is hundreds.
test "$(grep -c DEPS a/inside.out)" -lt 10

test "$(cd a && ./bin/test)" = "42"

# A second fragment, naming the sibling the way a build standing in
# "a" reaches it -- up one and back down, rather than from a top of
# the tree that is not where this build is.
test "$(ls a/obj/src/test.c/*.d | wc -l)" -eq 2
inside="$(ls a/obj/src/test.c/*.d | grep -v -x -F "$from_the_top")"
cat "$inside"
grep -q "^\.\./b/src/b.h:\$" "$inside"

# And it did not touch the one the build from the top reads.
grep -q "^b/src/b.h:\$" "$from_the_top"

##############################################################################
# ... and neither did anything to the other                                  #
##############################################################################
# Building from the top again, which is the half that used to be fine
# and has to stay that way.
make $MAKE_ARGS
test "$(./a/bin/test)" = "42"

# Editing the sibling's header rebuilds from both places, which is
# what makes either fragment worth having.
sleep 2
cat >b/src/b.h <<EOF
#define B_ANSWER 7
EOF

make $MAKE_ARGS
test "$(./a/bin/test)" = "7"

cat >b/src/b.h <<EOF
#define B_ANSWER 9
EOF

(cd a && timeout 60 make $MAKE_ARGS)
test "$(cd a && ./bin/test)" = "9"

exit 0
