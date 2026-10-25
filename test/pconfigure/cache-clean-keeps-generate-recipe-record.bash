#include "harness_start.bash"

# Beside every GENERATE's dependency fragment the configure leaves a
# record of the recipe that writes the fragment, and the next configure
# compares against it: a record that doesn't match -- or isn't there
# -- means the fragment was written by some other recipe, so it is
# deleted and "--deps" runs again.  The record is configure-time
# output with no rule behind it, which is exactly the kind of file
# "make cache-clean" reads the Makefile back and decides is stale, so
# it has to be spared by name the way the link-input records are.
# Otherwise the first reconfigure after a cache-clean throws away a
# good fragment and re-runs the script's "--deps" for nothing.
mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

GENERATE  += gen.h

BINARIES  += app
SOURCES   += app.c
EOF

echo 4 > src/answer.txt

# Counts its "--deps" runs.  The configure asks once on its own every
# time it runs, so what is held steady below is how many a reconfigure
# and build add, not the total.
cat >src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     echo run >> deps-runs; echo "src/answer.txt" ;;
--generate) echo "#define ANSWER $(cat src/answer.txt)" ;;
esac
EOF
chmod +x src/gen.h.proc

cat >src/app.c <<'EOF'
  #include "gen.h"
  #include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "4"

# The reconfigure on its own costs only the configure's own question:
# the record matches, the fragment stays and the build has nothing to
# do.  This is the baseline the cache-clean is held to.
cp deps-runs deps-runs.settled-before
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS > settled.out 2>&1
cat settled.out
grep -q "Nothing to be done" settled.out
settled=$(( $(wc -l < deps-runs) - $(wc -l < deps-runs.settled-before) ))

make $MAKE_ARGS cache-clean
cp deps-runs deps-runs.after-before
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS > after.out 2>&1
cat after.out
grep -q "Nothing to be done" after.out
if grep -q "^DEPS" after.out
then
    exit 1
fi
after=$(( $(wc -l < deps-runs) - $(wc -l < deps-runs.after-before) ))
test "$after" = "$settled"

exit 0
