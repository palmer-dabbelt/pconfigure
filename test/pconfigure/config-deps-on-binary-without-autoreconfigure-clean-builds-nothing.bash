#include "harness_start.bash"

# A CONFIG_DEPS on a binary pconfigure itself links, in a plain project
# (no BOOTSTRAP, no AUTORECONFIGURE).  Had the line become a recipe-less
# "Makefile: $(wildcard bin/main)" prerequisite, it would do nothing
# while bin/main is missing -- and once it exists the $(wildcard) is
# just bin/main, which has a rule, so make would relink it while
# remaking the makefiles it includes, before looking at the goal.
# "make -n clean" would then really compile and link, and "make clean"
# would build before it cleaned.  Nothing could ever act on the
# prerequisite here, so it must not be written at all.

mkdir -p src

cat >Configfile <<'EOC'
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
CONFIG_DEPS     += bin/main
EOC

echo 'int main(void) { return 0; }' > src/main.c

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS > first.log 2>&1 || { cat first.log; exit 1; }
cat first.log
test -x bin/main

# A source of the binary changes, so it is out of date, and the goal is
# one that does not ask for it.
before="$(stat -c %Y bin/main)"
sleep 1
echo '/* edited */' >> src/main.c

make $MAKE_ARGS -n clean > dry-run.log 2>&1 || { cat dry-run.log; exit 1; }
cat dry-run.log
test "$(stat -c %Y bin/main)" = "$before"

make $MAKE_ARGS clean > clean.log 2>&1 || { cat clean.log; exit 1; }
cat clean.log
if grep -qE '^(CC|LD|CP)[[:space:]]' clean.log
then
    exit 1
fi
