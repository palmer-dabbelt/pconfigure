#include "harness_start.bash"

# A header that a source includes has two lives: a file in the tree,
# and a name on the object's prerequisite line once pdeps has derived
# the fragment.  Deleting the file is where the two have to be
# reconciled on the next plain make (taxonomy type 12; the subproject
# variant is subproject-sibling-header-from-inside.bash's subject, and
# this is the plain-project variant the taxonomy flagged untested).
#
# pconfigure's answer to the deletion is the empty rule: pdeps writes
# "header:" with no recipe for every header it has ever seen, so make
# has a rule to run and does not stop with "No rule to make target",
# and does not loop.  What the empty rule does NOT do is make the
# object stale -- its prerequisites line still names the header, but
# nothing rebuilds the object from the *re-derived* fragment after the
# header has been dropped from it.  So the no-stop and no-loop halves
# of the correct behavior are what today's build delivers, and the
# recompile half -- the source recompiled against the new include
# graph, compiler error or not -- is the assertion this test is here
# to report on, unweakened.

export PATH="$(dirname "$PTEST_BINARY"):$PATH"

cat >Configfile <<EOF
AUTORECONFIGURE = true

LANGUAGES += c

BINARIES  += app
SOURCES   += main.c
SOURCES   += other.c
EOF

cat >src/helper.h <<'EOF'
#define HELPER 3
EOF

cat >src/main.c <<'EOF'
  #include "helper.h"
  #include <stdio.h>
int main(void) { printf("%d\n", HELPER); return 0; }
EOF

cat >src/other.c <<'EOF'
int other(void) { return 1; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS > first.out 2>&1
cat first.out
test "$(./bin/app)" = "3"

# pdeps recorded the header on the object's behalf, and wrote the
# empty rule for it -- the machinery the deletion will lean on.
test "$(ls obj/src/main.c/*-static.d | wc -l)" -eq 1
grep -q "^src/helper.h:$" obj/src/main.c/*-static.d

# A build that has nothing to do is the ordinary answer from here on,
# which is what makes the build after the deletion mean something.
make $MAKE_ARGS > settled.out 2>&1
cat settled.out
grep -q "Nothing to be done" settled.out

##############################################################################
# The header is deleted                                                      #
##############################################################################
sleep 2
rm src/helper.h

# Bounded, because a build that loops is one of the failure shapes
# this test exists to catch: the empty rule firing forever.
rc=0
timeout 60 make $MAKE_ARGS > second.out 2>&1 || rc=$?
cat second.out

# The build did not loop -- a quarter minute of nothing but DEPS lines
# is what the loop looked like when this machinery was built.
if test "$rc" -eq 124
then
    exit 1
fi

# The build did not stop: no "No rule to make target", the empty rule
# did its job.
if grep -q "No rule to make target" second.out
then
    exit 1
fi

# The source that included the deleted header was recompiled against
# the re-derived include graph -- the compiler's missing-header
# complaint is what a recompile attempt leaves in the log.  Unweakened:
# this is what correct incremental behavior looks like, and the test
# fails while the build settles for silence instead.
grep -q "^CC	main.c$" second.out

exit 0
