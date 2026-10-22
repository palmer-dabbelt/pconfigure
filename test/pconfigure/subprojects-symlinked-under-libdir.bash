#include "harness_start.bash"

top="$tempdir"

##############################################################################
# A symlink that reads as an ordinary name but lands under "lib/"            #
##############################################################################
# "make distclean" removes "lib/" whole, and a SUBPROJECTS whose path
# is spelled under "lib/" is refused for it.  "dep" is not spelled
# that way, but it is a symlink to "lib/dep", and the "rm -rf 'lib'"
# doesn't care what the tree was called: it takes the real checkout
# and leaves a dangling "dep" behind.  The object directory rule asks
# its question of the resolved directory for the same reason, and so
# this one has to as well.
mkdir -p $top/link/src $top/link/lib/dep/src
ln -s lib/dep $top/link/dep

cat >$top/link/Configfile <<'EOF'
SUBPROJECTS += dep

LANGUAGES   += c
BINARIES    += top
SOURCES     += top.c
EOF

cat >$top/link/lib/dep/Configfile <<'EOF'
LANGUAGES   += c
LIBRARIES   += libdep.so
SOURCES     += dep.c
EOF

echo 'int dep(void) { return 0; }' > $top/link/lib/dep/src/dep.c
echo 'int main(void) { return 0; }' > $top/link/src/top.c

if (cd $top/link && $PTEST_BINARY $PCONFIGURE_ARGS) > $top/link.out 2>&1
then
    cat $top/link.out
    # Show what the recipe that was just accepted would have done.
    (cd $top/link && make $MAKE_ARGS distclean)
    ls -l $top/link
    exit 1
fi
cat $top/link.out
grep -q "^\./Configfile:1 'SUBPROJECTS" $top/link.out
grep -q "'dep' resolves to '[^']*/lib/dep', which is inside '[^']*/lib'" \
    $top/link.out
grep -q "where libraries go" $top/link.out
test ! -e $top/link/Makefile
test -f $top/link/lib/dep/Configfile

##############################################################################
# A symlink that stays clear of every output directory                       #
##############################################################################
# Linking a vendored tree into place from elsewhere in the checkout is
# fine so long as where it lands isn't something distclean removes, so
# the same layout with the tree under "vendor/" builds, and distclean
# leaves both the link and the tree it points at alone.
mkdir -p $top/clear/src $top/clear/vendor/dep/src
ln -s vendor/dep $top/clear/dep
cp $top/link/Configfile $top/clear/Configfile
cp $top/link/lib/dep/Configfile $top/clear/vendor/dep/Configfile
cp $top/link/lib/dep/src/dep.c $top/clear/vendor/dep/src/dep.c
cp $top/link/src/top.c $top/clear/src/top.c

(cd $top/clear && $PTEST_BINARY $PCONFIGURE_ARGS)
(cd $top/clear && make $MAKE_ARGS)
test -x $top/clear/bin/top

(cd $top/clear && make $MAKE_ARGS distclean)
test ! -e $top/clear/bin/top
test -L $top/clear/dep
test -f $top/clear/vendor/dep/Configfile
test -f $top/clear/vendor/dep/src/dep.c

exit 0
