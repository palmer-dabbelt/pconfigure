#include "harness_start.bash"

# "make -r" turns off make's built-in rules -- something a parent
# build passing "-r" down in MAKEFLAGS does to everything under it.
# A generated Makefile writes every rule it needs out in full and
# cancels the built-ins it doesn't want itself, so it should build and
# test exactly as it does without the flag.

mkdir -p src test/hello

cat >Configfile <<'EOF'
LANGUAGES += c
LANGUAGES += bash

BINARIES  += hello
SOURCES   += hello.c
TESTSRC   += runs.bash
TESTSRC   += runs.c

BINARIES  += script
SOURCES   += script.bash
EOF

cat >src/hello.c <<'EOF'
int main(void) { return 0; }
EOF

cat >src/script.bash <<'EOF'
echo script
EOF

cat >test/hello/runs.bash <<'EOF'
"$PTEST_BINARY"
EOF

cat >test/hello/runs.c <<'EOF'
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS -r
./bin/hello
test "$(./bin/script)" = "script"

make $MAKE_ARGS -r check
test -f check/hello/runs.bash
test -f check/hello/runs.c
make $MAKE_ARGS -r report > report.out
grep -q "NPASS	2" report.out

exit 0
