#include "harness_start.bash"

# Inside a subproject an absolute SUBPROJECTS did something worse than
# be accepted: the subproject's own directory was glued onto the front
# of it before anything looked, "a/" + "/b" normalized to "a/b", and
# the line quietly turned into a relative one.  Run pconfigure in "a"
# and the same "/b" means the root of the filesystem's "b" instead.
# One line naming two directories depending on where pconfigure ran is
# what the path rules exist to prevent, so it is refused from both.
mkdir -p a/b

echo "SUBPROJECTS += a" > Configfile
echo "SUBPROJECTS += /b" > a/Configfile
echo "" > a/b/Configfile

if $PTEST_BINARY $PCONFIGURE_ARGS > above.out 2>&1
then
    cat above.out
    # What it did instead: read a/b as though "b" had been written.
    ls a/b/obj || true
    exit 1
fi
cat above.out
grep -q "SUBPROJECTS can't name an absolute path" above.out
grep -q "a/Configfile:1" above.out

if (cd a && $PTEST_BINARY $PCONFIGURE_ARGS) > inside.out 2>&1
then
    cat inside.out
    exit 1
fi
cat inside.out
grep -q "SUBPROJECTS can't name an absolute path" inside.out

exit 0
