#include "harness_start.bash"

# ptest runs every test in a directory of its own out of mktemp, which
# means wherever $TMPDIR says, and that is the user's to set rather
# than the project's.  One with a space in it is an ordinary home
# directory's worth of path.  That directory is tarred up after a cd
# and then removed, and a split path goes wrong differently in each:
# the cd fails and the tar collects whatever directory ptest happened
# to be in, and the rm is handed "<here>/my" and a relative "tmp/...",
# neither of which is the directory it made.
mkdir -p src test/main "my tmp"

# The first of those is somebody else's directory, so there is one
# here for it to remove.
mkdir -p my
echo "keep" > my/keep.txt

echo 'int main(void) { return 0; }' > src/main.c

# The test leaves a file of its own behind, which is the evidence that
# the result really is the test's directory and not one that happens
# to also have a ptest__return in it.
cat >test/main/t.bash <<'EOF2'
$PTEST_BINARY
echo "ran" > "$PTEST_TMPDIR"/marker
EOF2

cat >Configfile <<EOF2
LANGUAGES += c
LANGUAGES += bash

BINARIES  += main
SOURCES   += main.c
TESTSRC   += t.bash
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
TMPDIR="$(pwd)/my tmp" make $MAKE_ARGS check

test "$(tar -xOf check/main/t.bash ptest__return)" = 0
test "$(tar -xOf check/main/t.bash marker)" = ran

# Nothing is left behind in it, either: the scratch directory went
# when ptest was done with it.
test -z "$(ls -A "my tmp")"
test "$(cat my/keep.txt)" = keep
