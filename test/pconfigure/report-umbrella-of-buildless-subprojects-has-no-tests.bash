#include "harness_start.bash"

# When nothing anywhere in the build has a check directory, the
# report rule has no directory to name.  ptest given no directory goes
# looking for one, and falls back to "check" -- which here is a
# directory somebody wrote by hand, not results.  The build has to say
# outright that there are none, both on the report's command line and
# in the list a bare "ptest" reads.

mkdir -p check sub
echo "release checklist" > check/README

cat >Configfile <<'EOF2'
LANGUAGES   += bash
SUBPROJECTS += sub
EOF2

cat >sub/Configfile <<'EOF2'
LANGUAGES += bash
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS check

make $MAKE_ARGS report > report.out
cat report.out
grep -q "^No tests$" report.out

ptest="$(dirname "$PTEST_BINARY")/ptest"
"$ptest" --no-check-make-check > ptest.out
cat ptest.out
grep -q "^No tests$" ptest.out

exit 0
