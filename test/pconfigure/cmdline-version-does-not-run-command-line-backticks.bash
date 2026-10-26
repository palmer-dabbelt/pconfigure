#include "harness_start.bash"

# --version is documented to exit without touching anything else, so
# a Configfile line given with it -- the command somebody just ran,
# with --version added to see which pconfigure it was -- must not get
# its backticks run.
echo 'LANGUAGES += c' > Configfile

$PTEST_BINARY --version 'COMPILEOPTS += `touch ran-by-version`' > version.out 2>&1 || {
    cat version.out
    exit 1
}
cat version.out
grep -q "^pconfigure " version.out
test ! -e ran-by-version
test ! -e Makefile
