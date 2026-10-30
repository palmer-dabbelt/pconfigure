#include "harness_start.bash"

# A parent's "make check" covers every project it pulls in, so pulling
# in another one is a change to what "make check" means.  The library
# here was checked out and tested on its own first -- which is what
# anybody does before vendoring something -- and one of its tests
# failed.  Once it is a SUBPROJECTS of the parent, the parent's
# report lists that failure; the parent's "make check" has to fail
# with it, rather than finding its own stamp newer than everything
# it now waits on and saying nothing at all.

mkdir -p src test/t dep/src dep/test/helper

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES += t
SOURCES  += t.bash
TESTSRC  += passes.bash
EOF

cat >src/t.bash <<'EOF'
echo "Success"
EOF

cat >test/t/passes.bash <<'EOF'
exit 0
EOF

cat >dep/Configfile <<'EOF'
LANGUAGES += bash

LIBEXECS += helper
SOURCES  += helper.bash
TESTSRC  += fails.bash
EOF

cat >dep/src/helper.bash <<'EOF'
echo "Success"
EOF

cat >dep/test/helper/fails.bash <<'EOF'
exit 1
EOF

(
    cd dep
    $PTEST_BINARY $PCONFIGURE_ARGS
    make $MAKE_ARGS
    if make $MAKE_ARGS check
    then
        exit 1
    fi
)

sleep 1
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
make $MAKE_ARGS check

sleep 1
{ echo 'SUBPROJECTS += dep'; cat Configfile; } > Configfile.new && mv Configfile.new Configfile
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

if make $MAKE_ARGS report > report.out
then
    exit 1
fi
cat report.out
grep -q "FAIL	dep/helper/fails.bash" report.out

if make $MAKE_ARGS check > check.out 2>&1
then
    cat check.out
    exit 1
fi
cat check.out

exit 0
