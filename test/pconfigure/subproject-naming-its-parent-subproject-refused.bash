#include "harness_start.bash"

# One level further down than naming the top: "SUBPROJECTS += .." in
# "a/b" names "a", which is the subproject that pulled "a/b" in.  From
# the top that resolves to "a/", a project already being read, and the
# line used to be accepted and then skipped as a tree asked for twice
# -- so a cycle in the Configfiles read as nothing at all.  Run in "a"
# the same line names "a" itself and is refused, so from the top it
# is refused too, against the line in a/b's Configfile.  The same
# directory spelled the long way round, "../../a", is the same cycle.
mkdir -p a/b

echo "SUBPROJECTS += a" > Configfile
echo "SUBPROJECTS += b" > a/Configfile

for spelling in .. ../../a
do
    echo "SUBPROJECTS += $spelling" > a/b/Configfile

    if $PTEST_BINARY $PCONFIGURE_ARGS > above.out 2>&1
    then
        cat above.out
        exit 1
    fi
    cat above.out
    grep -q "SUBPROJECTS can't point at a directory that contains it" above.out
    grep -q "a/b/Configfile:1 'SUBPROJECTS += $spelling'" above.out
    test ! -e Makefile

    if (cd a && $PTEST_BINARY $PCONFIGURE_ARGS) > inside.out 2>&1
    then
        cat inside.out
        exit 1
    fi
    cat inside.out
    grep -q "b/Configfile:1 'SUBPROJECTS += $spelling'" inside.out
done

exit 0
