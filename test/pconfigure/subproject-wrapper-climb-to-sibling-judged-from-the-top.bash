#include "harness_start.bash"

# A wrapper project names a tree checked out beside it with "../tree",
# which is how a vendored build gets wrapped.  Climbing out is judged
# against the project pconfigure ran in: from the top, "wrap/../tree"
# is the top's own "tree" and has to be accepted, since that is the
# whole point of the wrapper.
#
# Run inside the wrapper, the same line names a directory beside the
# checkout and is refused -- but a bare "can't reach outside the
# project" about a line that works from the top reads as a bug.  The
# refusal says which project it was judged against and that running
# pconfigure from the one that has both is the way out.
mkdir -p wrap tree/src

echo "SUBPROJECTS += wrap" > Configfile
echo "SUBPROJECTS += ../tree" > wrap/Configfile

cat >tree/Configfile <<EOF2
LANGUAGES   += c
LIBRARIES   += libtree.so
SOURCES     += tree.c
EOF2
echo 'int tree(void) { return 0; }' > tree/src/tree.c

if ! $PTEST_BINARY $PCONFIGURE_ARGS > above.out 2>&1
then
    cat above.out
    exit 1
fi
cat above.out
test -e Makefile
grep -q "pconfigure_subdir_tree ?= tree/" Makefile
grep -q "src/tree.c" tree/obj/Makefile.tree

if (cd wrap && $PTEST_BINARY $PCONFIGURE_ARGS) > inside.out 2>&1
then
    cat inside.out
    exit 1
fi
cat inside.out
grep -q "SUBPROJECTS can't reach outside the project" inside.out
grep -q "'../tree' resolves to '../tree/'" inside.out
grep -q "run pconfigure from the project that has both" inside.out

exit 0
