#include "harness_start.bash"

# pconfigure copies a header into place while it configures, so that
# what includes it can be scanned, and it did that by running the
# recipe of every target BASH handed back for the HEADERS.  Under a
# HEADERS that includes the check target of any TESTSRC written there,
# so pconfigure ran a make recipe in a shell: "mkdir -p $(dir $@)"
# became a mkdir of whatever the "dir" command lists in the current
# directory -- which fails, because Configfile is a file -- and the
# run aborted with 'system("mkdir -p $(dir $@)") failed' and no line.
#
# A test under a HEADERS is a test of the header, run by "make check"
# like any other, and the only recipe configure has any business
# running is the copy of the header itself.
mkdir -p src test/api.h
echo 'int api(void);' > src/api.h
cat > test/api.h/t.bash <<'END'
touch $PTEST_TMPDIR/ran
END

cat >Configfile <<'END'
LANGUAGES += bash
LANGUAGES += h
HEADERS   += api.h
SOURCES   += api.h
TESTSRC   += t.bash
END

$PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1 || { cat out; exit 1; }
cat out
if grep -q 'system(' out
then
    exit 1
fi

# The header's own copy still happens at configure time ...
grep -q "int api(void);" include/api.h

# ... and the test is left for make, which runs it.
make $MAKE_ARGS check
tar -tf check/api.h/t.bash | grep -q "ran"
test "$(tar -xOf check/api.h/t.bash ptest__return)" = 0
