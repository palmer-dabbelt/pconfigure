#include "harness_start.bash"

# "CONFIG_DEPS += ." watches the project's own top directory, which is
# what a Configfile that turns every top-level directory into a
# SUBPROJECTS would name.  That directory is also where the build puts
# bin/, obj/ and the rest, so the first build after the configure
# changes it: one reconfigure follows, and then the tree has to settle
# rather than reconfigure on every make, since the configure itself
# must not leave the directory newer than the Makefile it wrote.

# The logs go a directory down, since a new file at the top is exactly
# what this line watches for.
mkdir -p src logs

cat >Configfile <<'EOC'
AUTORECONFIGURE  = true
CONFIG_DEPS     += .
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
EOC

echo 'int main(void) { return 0; }' > src/main.c

$PTEST_BINARY $PCONFIGURE_ARGS
grep -q '\$(wildcard \.)' Makefile

make $MAKE_ARGS > logs/first.log 2>&1 || { cat logs/first.log; exit 1; }
make $MAKE_ARGS > logs/second.log 2>&1 || { cat logs/second.log; exit 1; }
cat logs/first.log logs/second.log

# The configure's own writes must not count, so the first build runs
# against the Makefile it was handed.  That build makes bin/ at the top,
# so the second sees the directory newer than the Makefile and
# reconfigures, once.
if grep -q PCONFIGURE logs/first.log
then
    exit 1
fi
test "$(grep -c '^PCONFIGURE$' logs/second.log)" = 1

make $MAKE_ARGS > logs/third.log 2>&1 || { cat logs/third.log; exit 1; }
cat logs/third.log
if grep -q PCONFIGURE logs/third.log
then
    exit 1
fi
grep -q "Nothing to be done" logs/third.log

# And it still notices what it was written for.
sleep 1
touch new-entry
make $MAKE_ARGS > logs/fourth.log 2>&1 || { cat logs/fourth.log; exit 1; }
cat logs/fourth.log
grep -q "^PCONFIGURE$" logs/fourth.log
make $MAKE_ARGS > logs/fifth.log 2>&1 || { cat logs/fifth.log; exit 1; }
if grep -q PCONFIGURE logs/fifth.log
then
    exit 1
fi
