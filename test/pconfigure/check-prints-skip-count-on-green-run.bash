#include "harness_start.bash"

# "make check" is "ptest --quiet", and the quiet report prints the
# NSKIP count when it isn't zero precisely so that a suite that has
# quietly stopped running half of itself shows up on the terminal of
# the person who typed "make check".  The count went into the quiet
# report file, but the rule that wrote it only printed the file when
# the run failed -- so a green run with skips in it said nothing at
# all, which is the silence the count was added to break.

mkdir -p src test/t

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += t
SOURCES   += t.bash
TESTSRC   += skips.bash
TESTSRC   += passes.bash
EOF

echo 'echo hello' > src/t.bash
cat >test/t/skips.bash <<'EOF'
echo "SKIP: no hypervisor on this host"
exit 0
EOF
echo 'exit 0' > test/t/passes.bash

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS check > check.out 2>&1
cat check.out

grep -q "^NSKIP	1$" obj/check-report-quiet
grep -q "^NSKIP	1$" check.out

# A run with nothing to excuse has an empty quiet report, so printing
# it on success must not add a line to a clean "make check".
echo 'exit 0' > test/t/skips.bash
sleep 1
make $MAKE_ARGS check > green.out 2>&1
cat green.out
if grep -q "NSKIP" green.out
then
    exit 1
fi
test ! -s obj/check-report-quiet
