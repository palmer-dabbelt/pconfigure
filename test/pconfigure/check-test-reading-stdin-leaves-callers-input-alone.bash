#include "harness_start.bash"

# A script that walks a list and runs "make check" for each entry is
# the ordinary shape of a bisect or a matrix build, and the list is on
# the loop's stdin.  A test is run from inside that, and anything in
# it that reads stdin -- a "read" left in by mistake, an ssh, a tool
# that wants a confirmation -- takes the rest of the list with it, so
# the loop ends after one entry and says nothing about the others.
# The tests make runs are given nothing to read.

mkdir -p src test/t

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += t
SOURCES   += t.bash
TESTSRC   += reads.bash
EOF

echo 'echo hello' > src/t.bash

cat >test/t/reads.bash <<'EOF'
cat > "$PTEST_TMPDIR/stdin"
exit 0
EOF

$PTEST_BINARY $PCONFIGURE_ARGS

printf 'one\ntwo\nthree\n' > list
: > seen
while read -r entry
do
    echo "$entry" >> seen
    rm -rf check
    make $MAKE_ARGS check
done < list

cat seen
test "$(wc -l < seen)" = "3"

exit 0
