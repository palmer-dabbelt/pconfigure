#include "harness_start.bash"

# A CONFIG reads Configfiles/<name>, and nothing used to stop that file
# from naming itself -- a "CONFIG += common" copied into
# Configfiles/common is enough.  pconfigure then read the file again
# and again until its stack ran out, and died of SIGSEGV having printed
# nothing at all.  A cycle is a mistake in a Configfile like any other,
# so it is refused like one: an error naming the line that closed the
# loop, and no Makefile.
mkdir -p src Configfiles
echo 'int main(void) { return 0; }' > src/main.c

cat >Configfiles/common <<'EOF2'
BINARIES  += main
SOURCES   += main.c
CONFIG    += common
EOF2

cat >Configfile <<'EOF2'
LANGUAGES += c
CONFIG    += common
EOF2

set +e
$PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
status=$?
set -e
cat out
echo "status $status"

# A SIGSEGV shows up as 139; a refusal aborts, which is 134.  Either is
# non-zero, so what tells them apart is that a refusal says something.
test "$status" -ne 0
test "$status" -ne 139
grep -q "Configfiles/common:3 'CONFIG += common'" out
grep -q "error: .*Configfiles/common.* is already being read" out
grep -q "Configfile:2 'CONFIG += common'" out
test ! -e Makefile
