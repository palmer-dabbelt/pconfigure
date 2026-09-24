#include "harness_start.bash"

# Flipping a COMPILEOPTS has to reach the object, and with plain GNU
# make it cannot arrive through the rule: an object's prerequisites
# are its source and the headers pdeps reported, and make does not
# rebuild a target whose recipe changed (taxonomy types 11 and 12;
# the recipe blindness verified in the taxonomy's own experiment).
# What compensates is the object's path: pconfigure hashes the compile
# options into the object's directory, so a flag change is a new
# object rather than a rewritten one, and the new rule's target does
# not exist yet.  The old object is abandoned where it sits -- clean
# removes only what the current Makefile knows -- which is the price
# of the compensation and why the assertions below count the objects
# as well as the recompile.
#
# AUTORECONFIGURE is on because the flags live in the Configfile, and
# a Configfile edit is what the reconfigure rule watches.

export PATH="$(dirname "$PTEST_BINARY"):$PATH"

cat >Configfile <<EOF
AUTORECONFIGURE = true

LANGUAGES += c

BINARIES  += app
SOURCES   += app.c
COMPILEOPTS += -DVER=1
EOF

mkdir -p src

cat >src/app.c <<'EOF'
#include <stdio.h>
int main(void) { printf("%d\n", VER); return 0; }
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
# The compile options change                                                 #
##############################################################################
sleep 2
cat >Configfile <<EOF
AUTORECONFIGURE = true

LANGUAGES += c

BINARIES  += app
SOURCES   += app.c
COMPILEOPTS += -DVER=2
EOF

make $MAKE_ARGS > second.out 2>&1
cat second.out

# The reconfigure ran ...
grep -q "^PCONFIGURE$" second.out

# ... and the object recompiled, with nothing but its own mtime
# unchanged on any file -- the recompile fired on the options, which
# is the shape a command hash would give and a bare prerequisite line
# cannot.
grep -q "^CC	app.c$" second.out
grep -q "^LD	app$" second.out
test "$(./bin/app)" = "2"

# The compensation's shape: two objects sit in the source's object
# directory, the abandoned one and the current one, rather than one
# object rewritten in place.
test "$(ls obj/src/app.c/*-static.o | wc -l)" -eq 2

exit 0
