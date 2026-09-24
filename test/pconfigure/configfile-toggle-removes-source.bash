#include "harness_start.bash"

# Commenting a source out of a Configfile has three things to do: the
# Makefile stops naming its object, the binary relinks without it, and
# the binary's behavior stops reflecting its code.  The first is
# pconfigure's -- the link rule's prerequisite list shrinks, and the
# reconfigure rule rewrites the Makefile (taxonomy types 9 and 10).
# The second two are make's -- and make compares only the
# prerequisites that remain: a target whose prerequisite list shrank
# while the target itself is newer than everything left on it is up to
# date, and the link does not run.
#
# So the assertions are split on purpose.  The Makefile-side one is
# the part pconfigure owns and is expected to hold.  The binary-side
# one -- the removed object's code gone from the binary -- is the
# correct incremental behavior spelled out unweakened, and it is the
# one this test is here to report on: a build that leaves the removed
# object's code linked in is a stale rebuild, and the symbol is the
# observable.

export PATH="$(dirname "$PTEST_BINARY"):$PATH"

cat >Configfile <<EOF
AUTORECONFIGURE = true

LANGUAGES += c

BINARIES  += app
SOURCES   += main.c
SOURCES   += extra.c
EOF

cat >src/main.c <<'EOF'
int main(void) { return 0; }
EOF

cat >src/extra.c <<'EOF'
int extra(void) { return 1; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS > first.out 2>&1
cat first.out
nm bin/app | grep -q extra

# A build that has nothing to do is the ordinary answer from here on,
# which is what makes the build after the edit mean something.
make $MAKE_ARGS > settled.out 2>&1
cat settled.out
grep -q "Nothing to be done" settled.out

##############################################################################
# The source is commented out of the build                                   #
##############################################################################
sleep 2
cat >Configfile <<EOF
AUTORECONFIGURE = true

LANGUAGES += c

BINARIES  += app
SOURCES   += main.c
EOF

make $MAKE_ARGS > second.out 2>&1
cat second.out

# The reconfigure ran, and the rewritten Makefile no longer names the
# removed source anywhere -- its compile rule, its link prerequisite,
# its clean entries are all gone.
grep -q "^PCONFIGURE$" second.out
if grep -q "extra" Makefile
then
    exit 1
fi

# The binary, though, was built from the source that pconfigure just
# stopped naming, and a binary that still carries the removed
# object's code is the stale-rebuild symptom this test reports: the
# link rule's prerequisite list shrank and make saw no reason to run
# it again.  Unweakened: this is what correct incremental behavior
# looks like, and the test fails while the build gets it wrong.
if nm bin/app | grep -q " extra"
then
    exit 1
fi

# And the binary still runs, whatever else it is.
./bin/app

exit 0
