#include "harness_start.bash"

# ptest captures a test's stdout and stderr, which is what makes a
# result the same thing whoever ran it.  stdin is the other half of
# that: left attached, a test that reads it gets whatever ptest was
# handed -- the terminal of somebody typing "make check", which hangs
# the test until a key is pressed, or the input of whatever script
# ran the build -- so the verdict depends on who was at the keyboard.
# A test is run with nothing to read.

ptest="$(dirname "$PTEST_BINARY")/ptest"

mkdir -p check

cat >reads.sh <<'EOF'
#!/bin/bash
cat > "$PTEST_TMPDIR/stdin"
exit 0
EOF
chmod +x reads.sh

echo "not for the test" | "$ptest" --test reads.sh --out check/reads

tar -xOf check/reads stdin > got
cat got
test ! -s got
test "$(tar -xOf check/reads ptest__return)" = "0"

exit 0
