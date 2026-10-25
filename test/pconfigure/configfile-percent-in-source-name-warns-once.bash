#include "harness_start.bash"

# A source's name goes onto a rule line just as a program's does, so a
# '%' in one is asked about too.  A TESTSRC is a TESTS and a SOURCES
# wearing one hat, and is asked once, as the line it was written as,
# rather than once for each of the commands it turns into.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += c

BINARIES  += hello
SOURCES   += 100%.c

TESTSRC   += pct%test.c
EOF

cat >src/100%.c <<'EOF'
int main(void) { return 0; }
EOF

cat >src/pct%test.c <<'EOF'
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
cat configure.out
grep -q "Configfile:4" configure.out
grep -qF "warning: SOURCES has a '%' in it: '100%.c'" configure.out
grep -q "Configfile:6" configure.out
grep -qF "warning: TESTSRC has a '%' in it: 'pct%test.c'" configure.out
test "$(grep -c "warning:" configure.out)" = 2

exit 0
