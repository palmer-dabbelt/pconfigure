#include "harness_start.bash"

# A cycle needn't be a file naming itself: Configfiles/a naming b and
# Configfiles/b naming a went round forever too, and died of SIGSEGV
# with nothing printed.  The line refused is the one that closes the
# loop, which is b's, and the complaint walks back through the CONFIG
# lines that got there so the whole loop can be seen from one message.
mkdir -p src Configfiles
echo 'int main(void) { return 0; }' > src/main.c

cat >Configfiles/a <<'EOF2'
BINARIES  += main
CONFIG    += b
EOF2

cat >Configfiles/b <<'EOF2'
SOURCES   += main.c
CONFIG    += a
EOF2

cat >Configfile <<'EOF2'
LANGUAGES += c
CONFIG    += a
EOF2

set +e
$PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
status=$?
set -e
cat out
echo "status $status"

test "$status" -ne 0
test "$status" -ne 139
grep -q "Configfiles/b:2 'CONFIG += a'" out
grep -q "Configfiles/a:2 'CONFIG += b'" out
grep -q "Configfile:2 'CONFIG += a'" out
test ! -e Makefile

# An executable Configfile is read by running it, and what it prints
# can close a loop just the same.
cat >Configfiles/b <<'EOF2'
#!/bin/sh
echo "SOURCES += main.c"
echo "CONFIG += a"
EOF2
chmod +x Configfiles/b

set +e
$PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
status=$?
set -e
cat out
echo "status $status"

test "$status" -ne 0
test "$status" -ne 139
grep -q "Configfiles/b:2 'CONFIG += a'" out
test ! -e Makefile
