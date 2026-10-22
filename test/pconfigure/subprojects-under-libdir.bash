#include "harness_start.bash"

top="$tempdir"

##############################################################################
# A subproject is not checked out inside the library directory               #
##############################################################################
# "lib/" is where a lot of projects keep the trees they vendor, and it
# is also the default LIBDIR -- one of the directories "make distclean"
# removes whole, because everything in there is output this build
# knows how to make again.  A SUBPROJECTS inside an object directory
# is refused for exactly that reason, and a tree under "lib/" is the
# same checkout one distclean away from being gone: the Configfile,
# the sources and anything not yet pushed.
#
# Only the object directory used to be asked about, so this one
# configured, built and then lost the subproject on the first
# distclean.  It is refused now, at the line that named the tree.
mkdir -p $top/libdep/src $top/libdep/lib/dep/src

cat >$top/libdep/Configfile <<'EOF'
SUBPROJECTS += lib/dep

LANGUAGES   += c
BINARIES    += top
SOURCES     += top.c
EOF

cat >$top/libdep/lib/dep/Configfile <<'EOF'
LANGUAGES   += c
LIBRARIES   += libdep.so
SOURCES     += dep.c
EOF

echo 'int dep(void) { return 0; }' > $top/libdep/lib/dep/src/dep.c
echo 'int main(void) { return 0; }' > $top/libdep/src/top.c

if (cd $top/libdep && $PTEST_BINARY $PCONFIGURE_ARGS) > $top/libdep.out 2>&1
then
    cat $top/libdep.out
    exit 1
fi
cat $top/libdep.out
grep -q "^\./Configfile:1 'SUBPROJECTS" $top/libdep.out
grep -q "'lib/dep' is inside 'lib', where libraries go" $top/libdep.out
grep -q "one distclean away from being gone" $top/libdep.out
grep -q "LIBDIR = " $top/libdep.out

# Stopped before writing anything, so there is no distclean to run.
test ! -e $top/libdep/Makefile
test -f $top/libdep/lib/dep/Configfile

##############################################################################
# Nor under one a subproject's own Configfile is the reason for              #
##############################################################################
# The same question, one project down: a subproject that builds a
# binary has a "lib/" of its own, and its own SUBPROJECTS names a tree
# in it.  The line pointed at is the subproject's, since that's the
# one that has to change.
mkdir -p $top/nested/sub/src $top/nested/sub/lib/inner

cat >$top/nested/Configfile <<'EOF'
SUBPROJECTS += sub
EOF

cat >$top/nested/sub/Configfile <<'EOF'
LANGUAGES   += c
BINARIES    += subtool
SOURCES     += subtool.c

SUBPROJECTS += lib/inner
EOF
echo 'int main(void) { return 0; }' > $top/nested/sub/src/subtool.c
echo "" > $top/nested/sub/lib/inner/Configfile

if (cd $top/nested && $PTEST_BINARY $PCONFIGURE_ARGS) > $top/nested.out 2>&1
then
    cat $top/nested.out
    exit 1
fi
cat $top/nested.out
grep -q "^sub/Configfile:5 'SUBPROJECTS" $top/nested.out
grep -q "'sub/lib/inner' is inside 'sub/lib'" $top/nested.out
test ! -e $top/nested/Makefile

##############################################################################
# A project that builds nothing has no "lib/" to lose it to                  #
##############################################################################
# What distclean removes is the output directories of the targets
# there are, and a project that only pulls in other projects has none:
# its recipe names its object directory and nothing else.  So the same
# line is fine there, and refusing it would be a rule about the
# spelling rather than about what the recipe does.
mkdir -p $top/bare/lib/dep/src
cp $top/libdep/lib/dep/Configfile $top/bare/lib/dep/Configfile
cp $top/libdep/lib/dep/src/dep.c $top/bare/lib/dep/src/dep.c

cat >$top/bare/Configfile <<'EOF'
SUBPROJECTS += lib/dep
EOF

(cd $top/bare && $PTEST_BINARY $PCONFIGURE_ARGS)
(cd $top/bare && make $MAKE_ARGS)
test -f $top/bare/lib/dep/lib/libdep.so

(cd $top/bare && make $MAKE_ARGS distclean)
test ! -e $top/bare/lib/dep/lib/libdep.so
test -f $top/bare/lib/dep/Configfile
test -f $top/bare/lib/dep/src/dep.c

##############################################################################
# A directory whose name merely starts with "lib"                            #
##############################################################################
# "library" is not inside "lib", and a project that vendors there has
# made no mistake at all.
mkdir -p $top/libish/src $top/libish/library/dep/src
cp $top/libdep/lib/dep/Configfile $top/libish/library/dep/Configfile
cp $top/libdep/lib/dep/src/dep.c $top/libish/library/dep/src/dep.c
cp $top/libdep/src/top.c $top/libish/src/top.c

cat >$top/libish/Configfile <<'EOF'
SUBPROJECTS += library/dep

LANGUAGES   += c
BINARIES    += top
SOURCES     += top.c
EOF

(cd $top/libish && $PTEST_BINARY $PCONFIGURE_ARGS)
(cd $top/libish && make $MAKE_ARGS)
test -x $top/libish/bin/top

(cd $top/libish && make $MAKE_ARGS distclean)
test ! -e $top/libish/bin/top
test -f $top/libish/library/dep/Configfile
test -f $top/libish/library/dep/src/dep.c

exit 0
