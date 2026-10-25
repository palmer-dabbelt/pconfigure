#include "harness_start.bash"

# A compiled script's rule names a record of the recipe it was built
# with, and a record newer than the script is what rebuilds it.  The
# first time that record is written, though, there may already be a
# script it never saw: one a bootstrap.sh compiled for itself, or one a
# pconfigure from before the record was kept built.  The record being
# new then says nothing about the script, and rebuilding it anyway costs
# a tree that bootstraps its own tool one more rebuild and one more
# reconfigure on every fresh checkout.  So the first record must leave a
# script that is up to date alone, and a later one that says something
# else must still rebuild it.
mkdir -p src

cat >src/tool.bash <<'EOF2'
#!/bin/bash
echo GREETING
EOF2

cat >Configfile <<EOF2
LANGUAGES   += bash

BINARIES    += tool
COMPILEOPTS += -DGREETING=hello
SOURCES     += tool.bash
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/tool)" = "hello"

# What a tree whose object directory has never had a record in it
# looks like, with the script built and up to date beside it.
sleep 2
find obj -name '*.recipe-inputs' -delete
test -z "$(find obj -name '*.recipe-inputs')"

$PTEST_BINARY $PCONFIGURE_ARGS
test -n "$(find obj -name '*.recipe-inputs')"
make $MAKE_ARGS > first.log 2>&1 || { cat first.log; exit 1; }
cat first.log
grep -q "Nothing to be done" first.log

# And from there on the record does its job.
sleep 2
sed -i 's/-DGREETING=hello/-DGREETING=goodbye/' Configfile
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/tool)" = "goodbye"

exit 0
