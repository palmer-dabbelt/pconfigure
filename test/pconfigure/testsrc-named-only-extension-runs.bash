#include "harness_start.bash"

# A BASH test is claimed by its ".bash" ending, and a test kept in a
# hidden file called just ".bash" has nothing but that ending.  It is
# still a ".bash" file -- "TESTSRC += d/.bash" was claimed and run all
# along -- so it has to be claimed here too rather than stopping
# configure with "Unable to find language".  Its result goes where any
# other test's does, under the target's name with the test's own name
# on the end, and a hidden name there mustn't hide it from the report:
# a failing ".bash" has to fail "make check".
mkdir -p src test/app
echo 'int main(void) { return 0; }' > src/app.c
echo 'true' > test/app/.bash
cat >Configfile <<'EOT'
LANGUAGES   += c
LANGUAGES   += bash
BINARIES    += app
SOURCES     += app.c
TESTSRC     += .bash
EOT

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS check
test "$(tar -xOf check/app/.bash ptest__return)" = 0

echo 'false' > test/app/.bash
if make $MAKE_ARGS check
then
    exit 1
fi
test "$(tar -xOf check/app/.bash ptest__return)" != 0
