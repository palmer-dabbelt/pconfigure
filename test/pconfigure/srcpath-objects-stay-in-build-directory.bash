#include "harness_start.bash"

# "--srcpath" separates the build directory from the sources, the way
# running a configure script from somewhere else does for autoconf.
# The point of that is that a build writes into its own directory and
# nowhere else: several builds can share one checkout, and a checkout
# can be read-only.  An object's path is its source's path under
# OBJDIR, though, and a source path that starts "../.." climbs right
# back out of OBJDIR -- one level further than OBJDIR is deep -- and
# lands the objects next to the build directory rather than in it.

mkdir -p checkout/src builds/one

cat >checkout/Configfile <<'EOF'
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
EOF

echo 'int main(void) { return 0; }' > checkout/src/main.c

# What is outside the build directory before the build, so that
# anything it wrote out there shows up as a difference.
before="$(find . -path ./builds/one -prune -o -print | sort)"

cd builds/one
$PTEST_BINARY $PCONFIGURE_ARGS --srcpath ../../checkout
make $MAKE_ARGS
test -x bin/main
cd ../..

after="$(find . -path ./builds/one -prune -o -print | sort)"
diff <(echo "$before") <(echo "$after")

exit 0
