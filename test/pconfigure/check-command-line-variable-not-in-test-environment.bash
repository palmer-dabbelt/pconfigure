#include "harness_start.bash"

# ptest unsets MAKEFLAGS because "nothing about the outer make's
# command line means anything to a test": a test that runs a make of
# its own must not be steered by how the outer one was invoked.  A
# variable set on that command line reaches a recipe by a second
# route, though -- make exports it into the environment as well as
# passing it in MAKEFLAGS -- and an environment variable is something
# every make a test runs reads.  "make check DESTDIR=..." is the case
# that bites: the staging directory meant for some later install of
# this project arrives in the test's environment.

mkdir -p src test/t

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += t
SOURCES   += t.bash
TESTSRC   += env.bash
EOF

echo 'echo hello' > src/t.bash

cat >test/t/env.bash <<'EOF'
env > "$PTEST_TMPDIR/env"
exit 0
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS check DESTDIR="$tempdir/stage" OUTER_MARKER=outer

tar -xOf check/t/env.bash env > env.out

# Only the two names this is about: the rest of an environment is
# nobody's business in a test log.
grep -E "^(DESTDIR|OUTER_MARKER)=" env.out || true

if grep -q "^DESTDIR=" env.out
then
    exit 1
fi
if grep -q "^OUTER_MARKER=" env.out
then
    exit 1
fi

exit 0
