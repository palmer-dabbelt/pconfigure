#include "harness_start.bash"

# A SUBPROJECTS naming a directory that isn't there -- or one that is
# there and empty, which is what a submodule nobody has checked out
# looks like -- is not a project anybody can build.  It is refused at
# configure time, naming the line and listing the build systems that
# were asked, rather than written into a Makefile that fails later on
# an include of a file that was never going to exist.
setup() {
    rm -rf case
    mkdir -p case
    cat >case/Configfile <<EOF
BUILD_SYSTEMS += cmake

SUBPROJECTS   += vendor/lib
EOF
}

setup
if (cd case && $PTEST_BINARY $PCONFIGURE_ARGS) > out 2>&1
then
    exit 1
fi
cat out
grep -q "Unable to find a build system for 'vendor/lib/'" out
grep -q "Configfile:3 'SUBPROJECTS += vendor/lib'" out
grep -q "^  pconfigure$" out
grep -q "^  cmake$" out
test ! -e case/Makefile

setup
mkdir -p case/vendor/lib
if (cd case && $PTEST_BINARY $PCONFIGURE_ARGS) > out 2>&1
then
    exit 1
fi
cat out
grep -q "Unable to find a build system for 'vendor/lib/'" out
grep -q "Configfile:3" out
test ! -e case/Makefile

exit 0
