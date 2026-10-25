#include "harness_start.bash"

# A HEADERS installed from a SOURCES that isn't there should go the way
# a missing C source goes: pconfigure writes the Makefile, and "make"
# says which file it can't find.  It used to go the other way, because
# pconfigure copies a header into place itself while it configures, so
# that what includes it can be scanned -- and it did that by running
# the copy whatever the state of its input.  "cp" said "cannot stat",
# pconfigure said 'system("... phc -i src/nothere.h ...") failed', and
# the run aborted without either message naming a Configfile line.
#
# A header that can't be copied yet is one there is nothing to copy
# early, not a mistake for configure to stop on: the file may well be
# about to arrive, and make is the thing that knows when it has.
mkdir -p src

cat >Configfile <<'END'
LANGUAGES += c
LANGUAGES += h
HEADERS   += api.h
SOURCES   += nothere.h
END

$PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1 || { cat out; exit 1; }
cat out
if grep -q 'system(' out
then
    exit 1
fi

# make is the one that notices, and it says which file it wanted.
if make $MAKE_ARGS >make.out 2>&1
then
    cat make.out
    exit 1
fi
cat make.out
grep -q "nothere.h" make.out

# And once the file is there, the same Makefile builds it, with no
# reconfigure in between: nothing about the missing file was baked in.
echo 'int api(void);' > src/nothere.h
make $MAKE_ARGS
grep -q "int api(void);" include/api.h
