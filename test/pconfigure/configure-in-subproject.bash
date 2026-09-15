#include "harness_start.bash"

# Configuring a subproject where it sits, which is the thing a build
# that kept one Makefile per directory could not do.
#
# A parent describing a subproject and the subproject describing
# itself are two descriptions of one tree, and they disagree about
# every path in it: from up here the subproject is a directory that
# other things are built beside, and from down there it is the whole
# of the world.  Both are right.  pconfigure writes both, and what
# keeps them apart is the name -- a parent writes into the
# subproject's object directory under a name built out of where the
# subproject sits in the run that wrote it, and leaves the Makefile at
# the top of the subproject to whoever is standing there.
#
# It used to refuse the second of those instead, and the refusal was
# not wrong for what it was protecting: with one name for both files,
# a configure from down here wrote the parent's file with every path
# spelled bare, and the parent then built the subproject into its own
# directories the next time anybody ran make.  Quietly, and as a
# success.
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
# What a configure at the top writes                                         #
##############################################################################
$PTEST_BINARY $PCONFIGURE_ARGS

# Into the object directory, under the subproject's path with the
# separators turned into dots -- and not to the Makefile at the top of
# the subproject, which is the file this whole test is about not
# touching.
test -f sub/obj/Makefile.sub
test ! -e sub/Makefile

# With the variable at the top of it that the parent sets to say where
# this project is, and an include naming it through that same
# variable.
grep -q "^pconfigure_subdir_sub ?=\$" sub/obj/Makefile.sub
grep -q "^include \$(pconfigure_subdir_sub)obj/Makefile.sub\$" Makefile

cp sub/obj/Makefile.sub from-the-top.mk

make $MAKE_ARGS
./bin/top
./sub/bin/subbin

##############################################################################
# ... and what a configure inside it writes                                  #
##############################################################################
(cd sub && $PTEST_BINARY $PCONFIGURE_ARGS)

# The Makefile at the top of the subproject, which is the one make
# gets run at from down there.  Nothing in it goes through a variable,
# because from down there there is nobody above to be found through
# one.
test -f sub/Makefile
if grep -q "pconfigure_subdir" sub/Makefile
then
    cat sub/Makefile
    exit 1
fi
grep -q "^obj/src/subbin.c/.*\.o:" sub/Makefile

# And it left the parent's copy exactly as it was, which is the whole
# of what moving the file bought.
cmp from-the-top.mk sub/obj/Makefile.sub

cp sub/Makefile from-inside.mk

##############################################################################
# Both of them build, and build the same things                              #
##############################################################################
rm -f sub/bin/subbin
(cd sub && make $MAKE_ARGS && ./bin/subbin)

# At the path the subproject says its binary is at, rather than at one
# named after the subproject underneath itself -- which is the shape
# the old failure had.
test -x sub/bin/subbin
test ! -e sub/sub
test ! -e sub/obj/sub

rm -f sub/bin/subbin
make $MAKE_ARGS
./bin/top
./sub/bin/subbin

# The same target, put there by the other build.  The two runs
# disagree about how to spell the path and agree about which file it
# is, which is what makes them two descriptions rather than two
# builds.
test -x sub/bin/subbin

##############################################################################
# ... and neither configure takes the other's file                           #
##############################################################################
$PTEST_BINARY $PCONFIGURE_ARGS
cmp from-inside.mk sub/Makefile

(cd sub && $PTEST_BINARY $PCONFIGURE_ARGS)
cmp from-the-top.mk sub/obj/Makefile.sub

##############################################################################
# ... and a cache-clean from inside does not eat it                          #
##############################################################################
# "make cache-clean" works by reading the Makefile back and keeping
# what it still knows how to build.  Run down here that is the
# subproject's own Makefile, which has never heard of the parent's
# copy sitting in the object directory beside everything else it is
# about to sweep.  Throwing it away would break a build somewhere
# else entirely, which is the kind of damage nobody thinks to go
# looking for.
(cd sub && make $MAKE_ARGS cache-clean)
cmp from-the-top.mk sub/obj/Makefile.sub

make $MAKE_ARGS
./bin/top
./sub/bin/subbin

exit 0
