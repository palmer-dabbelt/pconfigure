#include "harness_start.bash"

# The Makefile writes a deleted context file back through a recipe,
# and make hands each recipe line to the shell as one argument.  Linux
# caps a single exec argument at 128 KiB, so a recipe that puts a whole
# file on one line stops working once the file is large enough -- and
# a deps-context holds a line per source, so a binary with several
# hundred sources gets there.  The shell then never runs at all, make
# says "Argument list too long", and the build is as stuck as it was
# before there was any rule.  Nothing here is compiled: asking make for
# the context file alone is enough to see whether it comes back, byte
# for byte.

export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src

long="a-source-name-long-enough-that-a-few-hundred-of-them-fill-a-deps-context-past-what-one-exec-argument-can-hold"

cat >Configfile <<'EOF2'
AUTORECONFIGURE  = true
LANGUAGES       += c
BINARIES        += main
EOF2

for i in $(seq 1 900)
do
    echo "int f$i(void) { return $i; }" > "src/$long-$i.c"
    echo "SOURCES         += $long-$i.c" >> Configfile
done

$PTEST_BINARY $PCONFIGURE_ARGS

context="$(find obj -name 'deps-context-*' -size +200k | head -n 1)"
test -n "$context"
cp "$context" saved-context

rm -f "$context"
make $MAKE_ARGS "$context" > restore.log 2>&1 || { cat restore.log; exit 1; }
cat restore.log
cmp saved-context "$context"

# It went back through the Makefile, which compiled nothing to do it.
test ! -e bin/main

exit 0
