#include "harness_start.bash"

# "ptest" says whether its report is current by asking make about the
# stamp "make check" builds, and under a DEFAULT_TEST_SUITE that is the
# suite's stamp rather than the whole project's -- which pconfigure writes
# down in $OBJDIR/check-stamp.  Two things went missing with a deleted
# object directory: that file, so ptest asked about a stamp "make check"
# never builds, and the file saying which results the suite's stamp
# stands for, which had an empty rule and so counted as remade on every
# make -- leaving the right stamp out of date for good.  Either way a
# complete "make check" was followed by a warning that it wasn't.

ptest="$(dirname "$PTEST_BINARY")/ptest"

mkdir -p src test/suite

cat >Configfile <<'EOC'
LANGUAGES          += c
LANGUAGES          += bash
TEST_SUITES        += quick
TEST_SUITES        += network
DEFAULT_TEST_SUITE  = quick
BINARIES           += suite
SOURCES            += suite.c
TESTSRC[quick]     += fast.bash
TESTSRC[network]   += slow.bash
EOC

echo 'int main(void) { return 0; }' > src/suite.c
echo true > test/suite/fast.bash
echo true > test/suite/slow.bash

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS check

"$ptest" > before.log
cat before.log
if grep -q "WARNING" before.log
then
    exit 1
fi

rm -rf obj
make $MAKE_ARGS
make $MAKE_ARGS check

"$ptest" > after.log
cat after.log
if grep -q "WARNING" after.log
then
    exit 1
fi
