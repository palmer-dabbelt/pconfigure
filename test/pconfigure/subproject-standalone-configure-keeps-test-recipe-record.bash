#include "harness_start.bash"

# The record of how a test's script was built -- the ".recipe-inputs"
# file its rule depends on -- is written by every configure, and what
# it says is spelled from wherever that configure ran.  A subproject is
# configured both from the top and from inside itself, so a record with
# one name for both runs holds whichever ran last, and each configure
# makes the other's next "make check" rebuild the script and run the
# test again for nothing.  Everything else a configure writes for a
# build to read is named per run for this reason, and so is this.
mkdir -p sub/test/unit

cat >Configfile <<'EOF'
SUBPROJECTS += sub
EOF

cat >sub/Configfile <<'EOF'
LANGUAGES += bash
PHONY     += unit
TESTSRC   += runs.bash
EOF

echo 'exit 0' > sub/test/unit/runs.bash

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS check

(cd sub && $PTEST_BINARY $PCONFIGURE_ARGS)

# Configuring the subproject on its own changes nothing about the
# top's build of its test.
make $MAKE_ARGS check > top.out 2>&1
cat top.out
if grep -q "^BASH	\|^CHECK	" top.out
then
    exit 1
fi

# Nor, once the subproject has built its own copy, does configuring
# the top again change anything about that one.
(cd sub && make $MAKE_ARGS check)
$PTEST_BINARY $PCONFIGURE_ARGS
(cd sub && make $MAKE_ARGS check) > sub.out 2>&1
cat sub.out
if grep -q "^BASH	\|^CHECK	" sub.out
then
    exit 1
fi

exit 0
