#include "harness_start.bash"

# The files pconfigure writes for a build to read come back after the
# object directory holding them is deleted, and they come back saying
# exactly what the configure wrote.  The Makefile is what puts them
# back, through a recipe -- which is a line make expands and then a
# shell parses -- so a '$' or a quote anywhere in what they say is a
# chance to come back as something else.  A context that came back
# different would be pdeps working from options nobody asked for, and
# the next configure would see a change that never happened and
# rewrite it, rebuilding every dependency in the project.

export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src

cat >Configfile <<'EOF2'
AUTORECONFIGURE  = true
LANGUAGES       += c
COMPILEOPTS     += -DAPOS="'a'" -DCOST='"$$5"'
BINARIES        += main
SOURCES         += main.c
EOF2

cat >src/main.c <<'EOF2'
#include <stdio.h>
int main(void) { printf("%c %s\n", APOS, COST); return 0; }
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/main)" = "a \$5"

mkdir saved
cp -r obj saved/
written="$(cd saved && find obj -name 'deps-context-*' -o -name link-inputs)"
test -n "$written"

rm -rf obj bin
make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
test "$(./bin/main)" = "a \$5"

for f in $written
do
    cmp "saved/$f" "$f"
done

# Put back by the Makefile, not by a configure: this tree's Configfile
# didn't change, so nothing should have run one.
if grep -q PCONFIGURE second.log
then
    exit 1
fi

# And a configure now finds every one of them already saying what it
# would write, so it rewrites none and the build has nothing to do.
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS > settled.log 2>&1 || { cat settled.log; exit 1; }
cat settled.log
grep -q "Nothing to be done" settled.log

exit 0
