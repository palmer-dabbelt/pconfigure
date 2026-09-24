#include "harness_start.bash"

# Output directories are order-only in spirit: they have to exist
# before a recipe runs, and their mtimes are never freshness carriers
# -- which is what keeps Kbuild's "| kdir" (taxonomy type 16) from
# re-outdating everything in a directory whenever a file lands in it.
# pconfigure gets the same property by construction: its recipes carry
# their own "mkdir -p", and no rule makes a directory a prerequisite.
#
# This test abuses the built tree the way directory churn abuses it in
# practice -- stray files landing in obj/ and in the generated-files
# directory, a file created and removed, a directory created -- and
# asserts that a plain make answers with nothing to do.  A build that
# recompiles here is a spurious rebuild: no file prerequisite of any
# object moved.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

GENERATE  += gen.h

BINARIES  += app
SOURCES   += app.c
SOURCES   += other.c
EOF

echo 42 > src/input.txt

cat >src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     echo "src/input.txt" ;;
--generate) echo "#define ANSWER $(cat src/input.txt)" ;;
esac
EOF
chmod +x src/gen.h.proc

cat >src/app.c <<'EOF'
  #include "gen.h"
  #include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

cat >src/other.c <<'EOF'
int other(void) { return 9; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS > first.out 2>&1
cat first.out
test "$(./bin/app)" = "42"

make $MAKE_ARGS > settled.out 2>&1
cat settled.out
grep -q "Nothing to be done" settled.out

##############################################################################
# The output directories churn                                               #
##############################################################################
sleep 2
touch obj/stray.o
touch obj/proc/stray.txt
mkdir -p obj/proc/subdir
touch obj/proc/here.tmp
rm obj/proc/here.tmp

make $MAKE_ARGS > second.out 2>&1
cat second.out

# Nothing did: no recompile of either source, no regeneration of the
# generated file -- the directories' mtimes moved and moved nothing.
grep -q "Nothing to be done" second.out
if grep -qE "^(CC|GEN)	" second.out
then
    exit 1
fi

# And the binary still answers from the objects it already had.
test "$(./bin/app)" = "42"

exit 0
