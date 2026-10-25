#include "harness_start.bash"

# A "--srcpath" that names a directory which is there, but which isn't
# the top of a project -- the src/ inside one, say -- has no Configfile
# to read any more than running pconfigure in that directory does.  The
# check that "--srcpath" names a directory at all is satisfied, so it's
# the one about there being nothing to read that has to catch this, and
# it has to look for the Configfiles where "--srcpath" says they are
# rather than in the build directory.
mkdir -p checkout/src build
echo 'int main(void) { return 0; }' > checkout/src/hello.c
cat >checkout/Configfile <<'EOF2'
LANGUAGES += c
BINARIES  += hello
SOURCES   += hello.c
EOF2

if (cd build && $PTEST_BINARY $PCONFIGURE_ARGS --srcpath ../checkout/src) >out 2>&1
then
    cat out
    exit 1
fi
cat out
test ! -e build/Makefile
test ! -e build/obj
grep -q "none of ../checkout/src/Configfiles/local, .* or ../checkout/src/Configfile exists" out

# The same build directory pointed at the top of the checkout is fine.
(cd build && $PTEST_BINARY $PCONFIGURE_ARGS --srcpath ../checkout)
(cd build && make)
build/bin/hello
