#include "harness_start.bash"

# A project that vendors pconfigure and asks to be reconfigured when
# its Configfiles change.  bootstrap.bash covers the vendoring half and
# autoreconfigure.bash covers the reconfiguring half; what neither of
# them has is both at once, which is the shape every real user of this
# is in and the shape somebody reported as a bug.
#
# What they reported was that "make" on an unchanged-looking tree ran a
# whole configure.  It was right to.  They had added a line to a
# Configfile, and noticing that is the entire job AUTORECONFIGURE was
# given.  What made it look wrong was a separate defect -- the recipe
# that checks for a vendored pconfigure was not silenced, so its line
# printed first and the work that followed read as its doing.  The
# lesson worth keeping is not in either fix: it is that nothing here
# was pinned, so a "simplification" could have taken it away and the
# report would have looked satisfied.
#
# The assertion that matters most is the second one.  Reconfiguring
# once is what a person wants; reconfiguring and then stopping is what
# makes the tree usable at all, and the only thing that stops it is
# that makefile::write_to_file gives the file a new mtime every time.
# That is one plain fopen with nothing next to it saying why, sitting a
# function away from a write_if_changed that is there on purpose, so it
# reads exactly like an oversight somebody should tidy up.  Tidying it
# up turns every "make" in a tree like this into a full configure, and
# with a Configfile dated in the future into a loop that never ends.

here="$(pwd)"

mkdir -p src vendor/pconfigure/src

# The same stand-in vendored tree bootstrap.bash uses, and for the same
# reason: what is under test is the Makefile pconfigure writes, not
# pconfigure's own bootstrap.sh, so the tree only has to be shaped like
# one that bootstraps.  Both halves keep a log, because the whole
# question here is what ran and how many times.
cat >vendor/pconfigure/src/pconfigure.bash <<EOF
echo ran >> "$here/configures"
exec "$PTEST_BINARY" "\$@"
EOF

cat >vendor/pconfigure/Configfile <<EOF
LANGUAGES += bash

BINARIES  += pconfigure
SOURCES   += pconfigure.bash
EOF

cat >vendor/pconfigure/bootstrap.sh <<EOF
#!/bin/bash -e
echo ran >> "$here/bootstraps"
mkdir -p bin
{ echo '#!/bin/bash'; cat src/pconfigure.bash; } > bin/pconfigure
chmod +x bin/pconfigure
echo "# bootstrapped" > Makefile
EOF
chmod +x vendor/pconfigure/bootstrap.sh

# AUTORECONFIGURE above BOOTSTRAP, and pconfigure will not take it the
# other way round: the setting reaches the subprojects underneath it,
# and a BOOTSTRAP line is one of the things that reads a subproject, so
# a tree that said it second would have configured its vendored
# pconfigure without it and its own sources with it.
cat >Configfile <<EOF
AUTORECONFIGURE  = true
BOOTSTRAP        = vendor/pconfigure

LANGUAGES       += c

BINARIES        += hello
SOURCES         += hello.c
EOF

cat >src/hello.c <<EOF
#include <stdio.h>
int main(void) { printf("hello\n"); return 0; }
EOF

##############################################################################
# A fresh checkout                                                           #
##############################################################################
$PTEST_BINARY $PCONFIGURE_ARGS

cp Makefile Makefile.committed
rm -rf Makefile.pconfigure obj bin check
rm -rf vendor/pconfigure/Makefile vendor/pconfigure/bin vendor/pconfigure/obj

make $MAKE_ARGS
test "$(wc -l < bootstraps)" -eq 1
test "$(wc -l < configures)" -eq 1
test "$(./bin/hello)" = "hello"

##############################################################################
# An edit to a Configfile                                                    #
##############################################################################
# Which reconfigures, because that is what the setting is for.  A
# Configfile is the only statement anywhere of what this project is,
# and a build that went on using last week's answer would be a build
# that quietly stopped compiling a file somebody had just added.
sleep 1
touch Configfile

make $MAKE_ARGS
test "$(wc -l < configures)" -eq 2

##############################################################################
# And then it stops                                                          #
##############################################################################
# The rule that just fired rewrote its own target, so asking again has
# nothing left to ask about.  This is the one that goes red if the
# unconditional write in makefile::write_to_file ever becomes a
# conditional one: the Makefile would come back with the Configfile
# still newer than it, make would remake it, restart, and arrive here
# again, for as long as anybody let it.
make $MAKE_ARGS > again.out 2>&1
cat again.out
test "$(wc -l < configures)" -eq 2
grep -q "Nothing to be done" again.out

##############################################################################
# An edit to a source                                                        #
##############################################################################
# Which does not.  Asserted next to the Configfile edit on purpose:
# what this pair says is where the line is, and a test that only
# checked the side that fires would go on passing if the line moved to
# take everything in.
sleep 1
touch src/hello.c

make $MAKE_ARGS
test "$(wc -l < configures)" -eq 2
test "$(wc -l < bootstraps)" -eq 1

##############################################################################
# And neither does the vendored tree's Makefile                              #
##############################################################################
# That file is the rule's order-only prerequisite, which is a way of
# saying the rule cares whether it exists and not whether it is new.
# It is worth checking rather than assuming, because the alternative
# reading -- that make counts a target out of date when an order-only
# prerequisite was remade during the run -- is a plausible-sounding
# thing that would make the order-only decorative, and would send the
# next person to read this rule looking for a defect that is not in it.
#
# Touched rather than deleted.  Deleting it would run the real
# bootstrap.sh, which is a different question from this one: what is
# being asked here is about a timestamp.
sleep 1
touch vendor/pconfigure/Makefile

make $MAKE_ARGS
test "$(wc -l < configures)" -eq 2
test "$(wc -l < bootstraps)" -eq 1

# None of which was worth rewriting the file make was started on.
cmp Makefile Makefile.committed

exit 0
