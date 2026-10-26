#include "harness_start.bash"

# A BASH script's name doesn't carry its options: it is rebuilt because
# a record of the command it was made with is rewritten whenever that
# command changes.  That makes a revert an ordinary change -- the
# record moves back and is newer than the script -- unlike an object
# named by a hash of its options, which a revert finds already built.
# Pinned so the two kinds of target are told apart if either changes.

mkdir -p src

cat >src/app.bash <<'EOS'
#!/bin/bash
echo VAL
EOS

configure_with() {
    cat >Configfile <<EOC
LANGUAGES   += bash
BINARIES    += app
COMPILEOPTS += -DVAL=$1
SOURCES     += app.bash
EOC
    $PTEST_BINARY $PCONFIGURE_ARGS
}

configure_with 1
make $MAKE_ARGS
test "$(./bin/app)" = "1"

sleep 2
configure_with 2
make $MAKE_ARGS
test "$(./bin/app)" = "2"

sleep 2
configure_with 1
make $MAKE_ARGS
test "$(./bin/app)" = "1"

# And settled once it has caught up.
make $MAKE_ARGS > settled.log 2>&1
cat settled.log
grep -q "Nothing to be done" settled.log
