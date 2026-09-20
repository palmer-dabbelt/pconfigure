#include "harness_start.bash"

top="$tempdir"

##############################################################################
# A subproject is not checked out inside an object directory                 #
##############################################################################
# pconfigure owns every byte under an object directory.  That is the
# sentence an install prefix rests on -- see build_system::install_dir()
# -- and it is not just a licence, it is what "make distclean" acts
# on: the recipe is an "rm -rf" of the object directory and nothing
# finer, because everything under there is output this build knows how
# to make again.
#
# A tree checked out in there is not output, and nothing about the
# recipe says so.  So the first distclean after somebody writes the
# line takes the checkout with it, and what is lost is whatever had
# not been pushed -- from a Configfile line that was read without a
# murmur and a target whose whole job is to be safe to run.
#
# Both kinds of subproject, because they are two different things
# behind one command: a vendored tree is built by running its own
# build system, and a pconfigure subproject is read into this run.
# Only the first of those has a build system to pick, so a check
# written anywhere below the picking would catch one and not the
# other.

##############################################################################
# A vendored tree                                                            #
##############################################################################
mkdir -p $top/vendored/obj/vend
cat >$top/vendored/obj/vend/configure <<'EOF'
#!/bin/sh
echo configured > config.status
EOF
chmod +x $top/vendored/obj/vend/configure
printf 'all:\n\t@true\n' > $top/vendored/obj/vend/Makefile.in

cat >$top/vendored/Configfile <<'EOF'
BUILD_SYSTEMS += autotools

SUBPROJECTS   += obj/vend
CONFIGUREOPTS += --no-install
EOF
cat $top/vendored/Configfile

if (cd $top/vendored && $PTEST_BINARY $PCONFIGURE_ARGS) \
    > $top/vendored.out 2>&1
then
    exit 1
fi
cat $top/vendored.out
grep -q "SUBPROJECTS can't name a directory inside an object directory" \
    $top/vendored.out
grep -q "'obj' is where this build writes" $top/vendored.out
grep -q "one distclean away from being gone" $top/vendored.out

# A configure that stopped wrote no Makefile.  Half a Makefile is
# worse than none at all, since make would go ahead and use it -- and
# the target it would go ahead and run is the one this is about.
test ! -e $top/vendored/Makefile

##############################################################################
# And a pconfigure subproject                                                #
##############################################################################
mkdir -p $top/pconf/obj/child/src
cat >$top/pconf/obj/child/Configfile <<'EOF'
LANGUAGES += c

LIBRARIES += libchild.so
SOURCES   += child.c
EOF
echo 'int child(void) { return 1; }' > $top/pconf/obj/child/src/child.c

cat >$top/pconf/Configfile <<'EOF'
SUBPROJECTS += obj/child
EOF

if (cd $top/pconf && $PTEST_BINARY $PCONFIGURE_ARGS) > $top/pconf.out 2>&1
then
    exit 1
fi
cat $top/pconf.out
grep -q "SUBPROJECTS can't name a directory inside an object directory" \
    $top/pconf.out
test ! -e $top/pconf/Makefile

##############################################################################
# Deeper in is still in                                                      #
##############################################################################
# The character after the object directory's name has to be a '/' for
# anything to be inside it, and everything under there is under there
# however many directories down: a "vendor" beside the object files is
# the shape somebody actually writes, because it looks like a place
# nothing else is using.
mkdir -p $top/deep/obj/vendor/tree
echo "" > $top/deep/obj/vendor/tree/Configfile

cat >$top/deep/Configfile <<'EOF'
SUBPROJECTS += obj/vendor/tree
EOF

if (cd $top/deep && $PTEST_BINARY $PCONFIGURE_ARGS) > $top/deep.out 2>&1
then
    exit 1
fi
cat $top/deep.out
grep -q "SUBPROJECTS can't name a directory inside an object directory" \
    $top/deep.out
test ! -e $top/deep/Makefile

##############################################################################
# A directory whose name merely starts with the object directory's           #
##############################################################################
# Which is the case a check written as "the path starts with 'obj'"
# lets through in the wrong direction: "objects" is not inside "obj",
# and a project that keeps its vendored trees there has made no
# mistake at all.  Refusing it would be a refusal of somebody's
# perfectly good layout, said in the words of a rule about
# distclean.
mkdir -p $top/objish/objects/child
echo "" > $top/objish/objects/child/Configfile

cat >$top/objish/Configfile <<'EOF'
SUBPROJECTS += objects/child
EOF

(cd $top/objish && $PTEST_BINARY $PCONFIGURE_ARGS)
test -f $top/objish/Makefile

# And what distclean does with it, which is the whole reason the
# refusal above exists: the object directory goes, and the checkout
# beside it stays.
(cd $top/objish && make $MAKE_ARGS distclean)
test -f $top/objish/objects/child/Configfile

##############################################################################
# The lexical refusal on its own, with nothing on disk to resolve           #
##############################################################################
# Every case above is caught twice over: once by the check that reads
# the path as written, and once more by the one that resolves it with
# realpath() and asks the same question of where the symlinks actually
# lead (see command_processor.c++, right after this one, and its own
# comment on why a project checked out through a symlink needs asking
# again).  mkdir -p put something real under every path those cases
# named, so the second check finds a real directory and fires right
# alongside the first -- which means removing the first one costs
# nothing here: the second one is still standing, still says the same
# sentence, and every assertion above still passes.
#
# realpath() answers "" for a path that resolves to nothing, and the
# check built on it is written to skip the question entirely when
# either side is that empty answer -- a directory that was never there
# is one no symlink could have pointed out of the tree, so there is
# nothing for that check to say.  The lexical check has no such
# get-out: it works from the text alone, before anything asks the
# filesystem whether the directory exists.  So a SUBPROJECTS naming a
# path lexically inside the object directory, where nothing was ever
# created at that path, is answered by the first check alone -- and is
# what tells the two apart.
mkdir -p $top/nodisk
cat >$top/nodisk/Configfile <<'EOF'
SUBPROJECTS += obj/never-created
EOF

if (cd $top/nodisk && $PTEST_BINARY $PCONFIGURE_ARGS) > $top/nodisk.out 2>&1
then
    exit 1
fi
cat $top/nodisk.out
grep -q "SUBPROJECTS can't name a directory inside an object directory" \
    $top/nodisk.out
grep -q "'obj' is where this build writes" $top/nodisk.out
test ! -e $top/nodisk/Makefile
test ! -e $top/nodisk/obj/never-created

exit 0
