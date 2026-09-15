#include "harness_start.bash"

# The Makefile an older pconfigure left at the top of a subproject.
#
# A parent used to write that file, and writes into the subproject's
# object directory now.  Upgrading pconfigure therefore leaves one
# behind in every subproject of every tree that has ever been
# configured: nothing includes it any more, and nothing deletes it
# either, because a build system that quietly removes a Makefile is a
# worse thing to be wrong about than a stale file is.
#
# Harmless where it sits and not harmless when somebody uses it.  A
# "make" run in the subproject finds it and builds out of whatever the
# tree looked like the last time a pconfigure that old ran -- with the
# old compile options, the old sources, and the old set of targets.
# Nothing about that looks like anything other than a build.
mkdir -p src sub/src

cat >Configfile <<EOF
LANGUAGES   += c
SUBPROJECTS += sub

BINARIES    += top
SOURCES     += top.c
EOF

cat >src/top.c <<'EOF'
int main(void) { return 0; }
EOF

cat >sub/Configfile <<EOF
LANGUAGES += c

BINARIES  += subbin
SOURCES   += subbin.c
EOF

cat >sub/src/subbin.c <<'EOF'
int main(void) { return 0; }
EOF

##############################################################################
# Nothing to say when there is nothing there                                 #
##############################################################################
# First, because a warning that fires on an ordinary tree is a warning
# everybody learns to scroll past.
$PTEST_BINARY $PCONFIGURE_ARGS > clean.out 2>&1
cat clean.out

if grep -q "older pconfigure" clean.out
then
    exit 1
fi

make $MAKE_ARGS
./bin/top
./sub/bin/subbin

##############################################################################
# What an older pconfigure left                                              #
##############################################################################
# Written out by hand rather than produced, because producing it would
# mean keeping a pconfigure old enough to write it.  The one detail it
# is recognized by is the variable declared with nothing after it:
# that is what a parent sets to say where this project is, and only a
# parent ever writes it -- a Makefile written from inside a project
# has no directory to be found through, so it has no such line.
cat >sub/Makefile <<'EOF'
pconfigure_subdir_sub ?=

all: $(pconfigure_subdir_sub)bin/ancient
EOF

$PTEST_BINARY $PCONFIGURE_ARGS > stale.out 2>&1
cat stale.out

# It says which file, and which variable made it say so, so that
# somebody who has never seen this before can go and look.
grep -q "'sub/Makefile' was written by an older pconfigure" stale.out
grep -q "'pconfigure_subdir_sub ?='" stale.out

# And which file this run wrote instead, which is the other half of
# the explanation: the description did not go away, it moved.
grep -q "wrote 'sub/obj/Makefile.sub' instead" stale.out

# What goes wrong if it is left, since "stale" on its own does not say
# whether this is tidiness or a real problem.
grep -q "would still find it and build out of whatever the tree looked like" stale.out

# Both ways out.
grep -q "delete it" stale.out
grep -q "run pconfigure in 'sub/'" stale.out

##############################################################################
# ... and it is a warning, not a refusal                                     #
##############################################################################
# The tree is fine.  The stale file is a thing to clean up rather than
# a thing that stops a build, and a configure that aborted over it
# would leave nobody able to build the tree they already had.
test -f sub/obj/Makefile.sub
make $MAKE_ARGS
./bin/top
./sub/bin/subbin

##############################################################################
# Configuring inside the subproject is one of the two ways out               #
##############################################################################
(cd sub && $PTEST_BINARY $PCONFIGURE_ARGS)

# What is there now is a Makefile for building this project where it
# sits, which is not the file the warning was about.
$PTEST_BINARY $PCONFIGURE_ARGS > fixed.out 2>&1
cat fixed.out

if grep -q "older pconfigure" fixed.out
then
    exit 1
fi

(cd sub && make $MAKE_ARGS && ./bin/subbin)

##############################################################################
# ... and deleting it is the other                                           #
##############################################################################
rm -f sub/Makefile

$PTEST_BINARY $PCONFIGURE_ARGS > gone.out 2>&1
cat gone.out

if grep -q "older pconfigure" gone.out
then
    exit 1
fi

make $MAKE_ARGS
./bin/top
./sub/bin/subbin

exit 0
