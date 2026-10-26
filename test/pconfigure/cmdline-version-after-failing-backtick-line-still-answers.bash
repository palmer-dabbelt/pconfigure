#include "harness_start.bash"

# --version says which pconfigure is installed, and nothing about the
# project should be able to stop it: a command-line line whose
# backtick fails is a configure-time problem, and --version doesn't
# configure.
echo 'LANGUAGES += c' > Configfile

status=0
$PTEST_BINARY 'PREFIX = `false`' --version > version.out 2>&1 || status=$?
cat version.out
test "$status" -eq 0
grep -q "^pconfigure " version.out
test ! -e Makefile
