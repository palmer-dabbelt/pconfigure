#include "harness_start.bash"

# A CONFIG name is looked up in Configfiles/, so "../Configfile" is the
# project's own top-level Configfile -- a path that stays inside the
# project and so isn't refused for leaving it, but which reads the file
# that is already being read.  pconfigure used to recurse until its
# stack ran out and be killed by SIGSEGV with nothing printed.  The
# top-level Configfiles are being read just as much as one a CONFIG
# named, so this is the same cycle and gets the same refusal.
mkdir -p src Configfiles
echo 'int main(void) { return 0; }' > src/main.c

cat >Configfile <<'EOF2'
LANGUAGES += c
BINARIES  += main
SOURCES   += main.c
CONFIG    += ../Configfile
EOF2

set +e
$PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
status=$?
set -e
cat out
echo "status $status"

test "$status" -ne 0
test "$status" -ne 139
grep -q "Configfile:4 'CONFIG += ../Configfile'" out
grep -q "error: .* is already being read" out
test ! -e Makefile
