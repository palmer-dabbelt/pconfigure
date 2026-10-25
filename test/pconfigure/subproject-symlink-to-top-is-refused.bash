#include "harness_start.bash"

# "SUBPROJECTS += ." is refused because a project can't be its own
# subproject, and so is any directory that contains it.  A symlink
# back to the top is the same directory under another name, and the
# manual says the rules about where a tree is are asked of the
# directory as well as of the name precisely because a symlink is where
# the two stop agreeing.  This one is asked of the name alone: "self/"
# isn't the top, so the top's Configfile is read again as "self", which
# names "self/self", and so on until the path is too long to open and
# the run ends complaining that there is no build system for
# 'self/self/self/...'.  It should be refused at the line, the way the
# plain spelling is.
ln -s . self

cat >Configfile <<'EOF'
SUBPROJECTS += self
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    cat out
    exit 1
fi
cat out | cut -c1-300

grep -q "Configfile:1 'SUBPROJECTS += self'" out
grep -q "can't point at the project itself" out
if grep -q "self/self/" out
then
    exit 1
fi
test ! -e Makefile

exit 0
