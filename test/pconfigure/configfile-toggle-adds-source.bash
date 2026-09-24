#include "harness_start.bash"

# Adding a source to a Configfile is the join direction of the toggle
# pair (taxonomy type 9): the reconfigure rule rewrites the Makefile
# with a new compile rule, a new object on the link line, and a link
# rule whose target does not exist yet -- which is the direction make
# handles by construction, since a missing prerequisite always gets
# built.  This is the counterpart of configfile-toggle-removes-source,
# where the shrinking direction is what make cannot see; here the new
# object's absence on disk is what drags the link along.
#
# The source file exists on disk before the line is added -- the case
# of a file written after the last configure, which is how sources
# join a tree in practice.

export PATH="$(dirname "$PTEST_BINARY"):$PATH"

cat >Configfile <<EOF
AUTORECONFIGURE = true

LANGUAGES += c

BINARIES  += app
SOURCES   += main.c
EOF

mkdir -p src

cat >src/main.c <<'EOF'
#include <stdio.h>
int main(void) { printf("1\n"); return 0; }
EOF

cat >src/extra.c <<'EOF'
int extra(void) { return 1; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS > first.out 2>&1
cat first.out
test "$(./bin/app)" = "1"

# A build that has nothing to do is the ordinary answer from here on,
# which is what makes the build after the edit mean something.
make $MAKE_ARGS > settled.out 2>&1
cat settled.out
grep -q "Nothing to be done" settled.out

##############################################################################
# The source joins the build                                                 #
##############################################################################
sleep 2
cat >Configfile <<EOF
AUTORECONFIGURE = true

LANGUAGES += c

BINARIES  += app
SOURCES   += main.c
SOURCES   += extra.c
EOF

make $MAKE_ARGS > second.out 2>&1
cat second.out

# The reconfigure ran, the new source was compiled, and the binary
# relinked with the new object.
grep -q "^PCONFIGURE$" second.out
grep -q "^DEPS	extra.c$" second.out
grep -q "^CC	extra.c$" second.out
grep -q "^LD	app$" second.out

# And the binary now answers from the joined source.
test "$(./bin/app)" = "1"
nm bin/app | grep -q extra

exit 0
