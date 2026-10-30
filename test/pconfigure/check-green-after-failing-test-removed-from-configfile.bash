#include "harness_start.bash"

# "make check" runs every test the Configfile names and fails when one
# of them did.  A test that has been taken out of the Configfile is no
# longer one of them, but its last result is still a tarball in the
# check directory, and the project-wide report used to read whatever
# the directory held.  Taking out the test that was failing -- the
# usual reason to take one out -- left "make check" red for good, about
# a test that no longer exists, and nothing the build offered short of
# distclean ever made it green again.

mkdir -p src test/t

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += t
SOURCES   += t.bash
TESTSRC   += stays.bash
TESTSRC   += goes.bash
EOF

echo 'echo hello' > src/t.bash
echo 'exit 0' > test/t/stays.bash
echo 'exit 1' > test/t/goes.bash

$PTEST_BINARY $PCONFIGURE_ARGS
if make $MAKE_ARGS check
then
    exit 1
fi

# The failing test goes, and nothing else changes.
sed -i.bak '/goes.bash/d' Configfile
$PTEST_BINARY $PCONFIGURE_ARGS

make $MAKE_ARGS check
make $MAKE_ARGS report > report.out
cat report.out
grep -q "^NRUN	1$" report.out
if grep -q "goes.bash" report.out
then
    exit 1
fi

exit 0
