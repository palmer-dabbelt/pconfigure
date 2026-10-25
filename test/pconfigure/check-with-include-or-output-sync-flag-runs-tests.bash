#include "harness_start.bash"

# ptest skips the test when $MAKEFLAGS says make is only printing,
# touching or asking ("make -n", "-t" or "-q").  Those modes are single
# letters at the very start of $MAKEFLAGS, but when no single-letter
# flag was given make starts it with a space and an option that carries
# its argument instead: " -Iinclude" for "make -I include", " -Otarget"
# for "make -Otarget".  Read as a word with the space and the dash
# stripped, each is all letters with an "n" or a "t" in it, and was
# taken for a dry run -- so every test was skipped, no result was
# written, and "make check" reported success for a test that fails.
#
# The outer make that runs this test has its own MAKEFLAGS and
# MAKELEVEL in the environment, and the inner make would fold them into
# what it hands ptest, so they are cleared to see exactly what a make
# started from a shell writes.

mkdir -p src test/t include

cat >Configfile <<'EOF2'
LANGUAGES += bash

BINARIES += t
SOURCES  += t.bash
TESTSRC  += side-effect.bash
TESTSRC  += fails.bash
EOF2

cat >src/t.bash <<'EOF2'
echo "Success"
EOF2

cat >test/t/side-effect.bash <<'EOF2'
echo "ran" >> "$PTEST_SRCDIR/ran.log"
exit 0
EOF2

cat >test/t/fails.bash <<'EOF2'
echo "ran" >> "$PTEST_SRCDIR/failed.log"
exit 1
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS

ptest="$(dirname "$PTEST_BINARY")/ptest"

for flag in "-I include" "-Otarget"
do
    rm -rf check ran.log failed.log

    # A failing test makes "make check" fail; it is the report that
    # follows that says so, and it can only say so if the test ran.
    if env -u MAKEFLAGS -u MFLAGS -u MAKELEVEL \
        make $MAKE_ARGS $flag check > check.out 2>&1
    then
        cat check.out
        exit 1
    fi
    cat check.out

    test "$(cat ran.log)" = "ran"
    test "$(cat failed.log)" = "ran"
    test "$(tar -xOf check/t/side-effect.bash ptest__return)" = 0
    test "$(tar -xOf check/t/fails.bash ptest__return)" != 0

    "$ptest" --no-check-make-check > report.out || true
    cat report.out
    grep -q "PASS	t/side-effect.bash" report.out
    grep -q "FAIL	t/fails.bash" report.out
done

exit 0
