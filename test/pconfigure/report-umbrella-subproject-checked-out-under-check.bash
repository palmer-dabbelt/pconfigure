#include "harness_start.bash"

# A subproject checked out under "check/" is refused when the project
# above it has results of its own to put there, because distclean
# would take the checkout.  An umbrella project with no targets has no
# such directory, so the checkout is let through -- and then the
# report mustn't read the checkout as results either: its Configfile,
# sources and object directory would each be an EROR, and its one
# real result would be counted twice, once from each of the two
# directories that hold it.

mkdir -p check/dep/src check/dep/test/d

cat >Configfile <<'EOF2'
LANGUAGES   += bash
SUBPROJECTS += check/dep
EOF2

cat >check/dep/Configfile <<'EOF2'
LANGUAGES += bash

BINARIES  += d
SOURCES   += d.bash
TESTSRC   += passes.bash
EOF2

echo 'echo hello' > check/dep/src/d.bash
echo 'exit 0' > check/dep/test/d/passes.bash

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS check

make $MAKE_ARGS report > report.out
cat report.out
grep -q "^NRUN	1$" report.out
grep -q "^NPASS	1$" report.out
grep -q "^NEROR	0$" report.out

# The checkout is still there after a distclean, which is the promise
# that let the SUBPROJECTS line through in the first place.
make $MAKE_ARGS distclean
test -e check/dep/Configfile
test -e check/dep/src/d.bash

exit 0
