#include "harness_start.bash"

# A ".d" fragment is not the answer the script gave: it is what one
# version of the DEPS recipe made of that answer.  So the recipe is an
# input to the fragment, and until the record this test is about,
# nothing anywhere said so.
#
# What that cost, measured in the tree that vendors pconfigure, on the
# configure that first taught "--deps" the '?' marker: the fragment on
# disk had been written by the previous recipe, which knew nothing of
# the marker and so prefixed the line without stripping it.  The
# Makefile beside it held the fixed sed.  What came out of a plain make
# was
#
#     make: *** No rule to make target
#     'src/pconfigure/?../../.git/modules/src/pconfigure/HEAD',
#     needed by 'src/pconfigure/obj/proc/version.h'.  Stop.
#
# A fragment is INCLUDED, so that is not one stale target: it stopped
# every target in that tree, "make reconfigure" included, because a tree
# that bootstraps its own pconfigure cannot configure without building
# pconfigure and could not build anything.  Deleting the file by hand
# was the only way out, which is a build system asking to be repaired
# rather than run.
#
# So the fragment is dropped by the CONFIGURE rather than by a rule: the
# recipe is recorded beside the fragment, and a configure whose recipe
# is not the recorded one throws the fragment away.  A prerequisite
# cannot do this job, and that is measured rather than assumed -- by the
# time make could act on the record the stale fragment has already been
# read and its lines are in force, so in the tree above make died on the
# fragment while still deciding what to remake, with a context file
# newer than the fragment and the rule naming it.
#
# Four things get pinned below, in the order a reader needs them.

mkdir -p sub/src

cat >Configfile <<EOF
SUBPROJECTS += sub
EOF

cat >sub/Configfile <<EOF
LANGUAGES += c

GENERATE  += gen.h

BINARIES  += app
SOURCES   += app.c
EOF

echo 1 > sub/src/base.txt

# One mandatory line and one optional line, because they take different
# routes through the sed and a fragment with only one kind in it cannot
# tell a re-derivation that got half the recipe from one that got all of
# it.
cat >sub/src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     echo "src/base.txt"
            echo "?src/opt.txt" ;;
--generate) echo "#define BASE $(cat src/base.txt)" ;;
esac
EOF
chmod +x sub/src/gen.h.proc

cat >sub/src/app.c <<'EOF'
  #include "gen.h"
  #include <stdio.h>
int main(void) { printf("%d\n", BASE); return 0; }
EOF

##############################################################################
# 1: the record exists and says what wrote the fragment                      #
##############################################################################
$PTEST_BINARY $PCONFIGURE_ARGS
timeout 60 make $MAKE_ARGS > first.out 2>&1 || { cat first.out; exit 1; }
cat first.out
test "$(./sub/bin/app)" = "1"

cat sub/obj/proc/gen.h.d
grep -qxF '$(pconfigure_subdir_sub)obj/proc/gen.h: $(pconfigure_subdir_sub)src/base.txt' sub/obj/proc/gen.h.d
grep -qxF '$(pconfigure_subdir_sub)obj/proc/gen.h: $(foreach f,$(wildcard $(pconfigure_subdir_sub)src/opt.txt),$(if $(realpath $(f)),$(f),))' sub/obj/proc/gen.h.d

# The sed that decides the fragment's whole format is in the record,
# which is what makes everything below a statement about the recipe
# rather than about a file somebody deleted.
test -f sub/obj/proc/gen.h.d-context
grep -q 'sed -e' sub/obj/proc/gen.h.d-context
grep -q '\^?' sub/obj/proc/gen.h.d-context
grep -q 'pconfigure_subdir_sub' sub/obj/proc/gen.h.d-context

##############################################################################
# 2: a configure that changed nothing costs nothing                          #
##############################################################################
# Before the interesting cases, because it is the one a regression hides
# in: a drop that fired every time would pass every assertion further
# down and quietly re-run every "--deps" script in the tree on every
# configure.  The record is compared by CONTENT for this reason, and
# nothing else here would notice if it stopped being.
sleep 2
$PTEST_BINARY $PCONFIGURE_ARGS
test -f sub/obj/proc/gen.h.d

timeout 60 make $MAKE_ARGS > noop.out 2>&1 || { cat noop.out; exit 1; }
cat noop.out
grep -q "Nothing to be done" noop.out
if grep -q "^DEPS	gen.h$" noop.out
then
    exit 1
fi

##############################################################################
# 3: the incident, and the recovery from it                                  #
##############################################################################
# The fragment is put into exactly the state the version.h incident left
# it in: the target spelled the way this build spells it, and the '?'
# prefixed rather than stripped, which is what a recipe that did not know
# about the marker made of this script's answer.  The record goes with
# it, because the pconfigure that wrote such a fragment kept none -- so
# "no record" is the state a tree upgrading across this change is in, and
# it has to count as a record that does not match.
#
# Hand-written because a test cannot hold two pconfigures.  Everything
# that follows from it is real.
#
# The control, measured against this same tree with the drop removed:
#
#     make: *** No rule to make target 'sub/?src/opt.txt',
#     needed by 'sub/obj/proc/gen.h'.  Stop.
#
# which is the incident in miniature.  "make reconfigure" does clear it
# here, where the toy project does not build the pconfigure that
# configures it; in the tree that does, it did not.
sleep 2
cat >sub/obj/proc/gen.h.d <<'EOF'
$(pconfigure_subdir_sub)obj/proc/gen.h: $(pconfigure_subdir_sub)src/base.txt
$(pconfigure_subdir_sub)obj/proc/gen.h: $(pconfigure_subdir_sub)?src/opt.txt
EOF
rm -f sub/obj/proc/gen.h.d-context

$PTEST_BINARY $PCONFIGURE_ARGS

# Gone before make has read anything, which is the whole mechanism.
if test -e sub/obj/proc/gen.h.d
then
    exit 1
fi
test -f sub/obj/proc/gen.h.d-context

timeout 60 make $MAKE_ARGS > recovered.out 2>&1 || { cat recovered.out; exit 1; }
cat recovered.out
grep -q "^DEPS	gen.h$" recovered.out

cat sub/obj/proc/gen.h.d
grep -qxF '$(pconfigure_subdir_sub)obj/proc/gen.h: $(pconfigure_subdir_sub)src/base.txt' sub/obj/proc/gen.h.d
grep -qxF '$(pconfigure_subdir_sub)obj/proc/gen.h: $(foreach f,$(wildcard $(pconfigure_subdir_sub)src/opt.txt),$(if $(realpath $(f)),$(f),))' sub/obj/proc/gen.h.d

# And the line that stopped the tree is nowhere in it.
if grep -q '?src/opt.txt' sub/obj/proc/gen.h.d
then
    exit 1
fi

test "$(./sub/bin/app)" = "1"

# It settles: the fragment comes back newer than the record that
# triggered it, so there is nothing left for the next make to do.
timeout 60 make $MAKE_ARGS > settled.out 2>&1 || { cat settled.out; exit 1; }
cat settled.out
grep -q "Nothing to be done" settled.out

##############################################################################
# 4: a real recipe change, and the single shared record                      #
##############################################################################
# A build from inside the subproject is a genuinely different recipe for
# the same fragment: every path loses the project's make variable.  It
# changes the recipe and NOTHING ELSE -- the script does not move, the
# directories it reads do not move, and their mtimes do not change -- so
# what happens here is attributable to the recipe alone.
#
# Two other triggers were tried first, and both are written down because
# both look right and neither measures this.  SRCDIR, moved from "src"
# to "source", does change the recipe -- the script's path is in it
# twice -- but it also moves the directory the fragment WATCHES, and a
# watched directory that has just been created is newer than the
# fragment: measured against a pconfigure with no record at all, the
# fragment was re-derived anyway, so the test passed without the fix it
# was written for.  OBJDIR changes the sed's target name and moves the
# fragment with it, leaving the stale file under an object directory
# nothing includes, so there is no stale fragment for anything to notice.
#
# The control here is quieter than the one above, and the reason is
# worth writing down because it makes the assertions below the only
# evidence there is.  With the drop removed, the standalone make kept the
# parent's fragment and went GREEN: a subproject's Makefile defines its
# own prefix variable as empty, so a fragment written for a parent
# collapses to the standalone spelling when read from inside, and is
# accidentally right.  Measured, app and all.  Nothing about the build
# says anything, in either direction -- the other way round, measured
# too, a standalone fragment read by the parent's make keeps naming
# "obj/proc/gen.h", which is not the "sub/obj/proc/gen.h" that build
# asks for, so its lines are inert and the parent also goes green.  A
# later input arriving would go unwatched with nothing said, which is the
# failure this whole convention exists to end, so what is checked here is
# the file rather than the exit status.
#
# This is also where the record's single name is pinned.  Suffixing it
# per project -- one record for a standalone run and another for a
# parent's, which is what the kconfig build system does with its own
# contexts -- would leave the standalone record saying what it said
# before the parent ever ran, so it would MATCH while the fragment
# beside it had been written by the parent's recipe: a key that has
# stopped describing the thing it is the key for.  Shared, a mismatch
# always means what it says.
sleep 2
cd sub
$PTEST_BINARY $PCONFIGURE_ARGS

if test -e obj/proc/gen.h.d
then
    exit 1
fi

timeout 60 make $MAKE_ARGS > standalone.out 2>&1 || { cat standalone.out; exit 1; }
cat standalone.out
grep -q "^DEPS	gen.h$" standalone.out

cat obj/proc/gen.h.d
grep -qxF 'obj/proc/gen.h: src/base.txt' obj/proc/gen.h.d
grep -qxF 'obj/proc/gen.h: $(foreach f,$(wildcard src/opt.txt),$(if $(realpath $(f)),$(f),))' obj/proc/gen.h.d
if grep -q 'pconfigure_subdir_sub' obj/proc/gen.h.d
then
    exit 1
fi

test "$(./bin/app)" = "1"

exit 0
