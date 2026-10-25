#include "harness_start.bash"

# The objects of a project built with "--srcpath" belong under OBJDIR
# just as they would without it, and that includes the ones built from
# its tests.  A source's object is named after where the source sits
# in the project, not after how far the build directory happens to be
# from the checkout: the ".." in "../checkout" used to cancel out the
# "obj", so these landed in a "checkout" directory beside "obj" in the
# build directory.  That's one ".." short of
# srcpath-objects-stay-in-build-directory.bash, and it shows the
# objects being in the wrong place even when they don't escape.

mkdir -p checkout/src checkout/test/main build

cat >checkout/Configfile <<'EOF'
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
TESTSRC         += passes.c
EOF

echo 'int main(void) { return 0; }' > checkout/src/main.c
echo 'int main(void) { return 0; }' > checkout/test/main/passes.c

cd build
$PTEST_BINARY $PCONFIGURE_ARGS --srcpath ../checkout
make $MAKE_ARGS
make $MAKE_ARGS check

test -x bin/main
test "$(tar -xOf check/main/passes.c ptest__return)" = "0"

# Every object, the test's included, is somewhere under "obj", and is
# named from the project's own "src" and "test" rather than from the
# path back to the checkout.
find . -name '*.o' | sort > objects
cat objects
test -s objects
if grep -v '^\./obj/' objects
then
    exit 1
fi
grep -q '^\./obj/src/main\.c/' objects
grep -q '^\./obj/test/main/passes\.c/' objects
test ! -e checkout

exit 0
