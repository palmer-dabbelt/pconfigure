#include "harness_start.bash"

# make drops a "./" from the front of every target it reads, so a PHONY
# written as "./clean" is a rule called "clean" all the same, and merges
# with the real one: "make clean" built the PHONY's TESTDEPS first and
# never got as far as cleaning when they didn't compile.  The spelling
# on the line is no way around the refusal of "clean", and the message
# says what make makes of it, since "./clean" isn't the name that was
# refused.  A run of "./" and doubled slashes reads the same way.

mkdir -p src

cat >Configfile <<'EOC'
LANGUAGES += c
PHONY     += ./clean
TESTDEPS  += bin/t

PHONY     += .//./distclean
TESTDEPS  += bin/t

BINARIES  += t
SOURCES   += t.c
EOC

echo 'int main(void) { return 0' > src/t.c

if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
then
    cat configure.out
    echo "PHONY += ./clean was accepted" >&2
    exit 1
fi
cat configure.out

grep -q "^./Configfile:2" configure.out
grep -qF "error: PHONY can't be called './clean': make reads that as 'clean'" configure.out
grep -qF "give the PHONY a name of its own" configure.out
test ! -e Makefile

# The second spelling on its own, now that the first is out of the way.
sed -i '2,3d' Configfile
if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
then
    cat configure.out
    echo "PHONY += .//./distclean was accepted" >&2
    exit 1
fi
cat configure.out

grep -q "^./Configfile:3" configure.out
grep -qF "make reads that as 'distclean'" configure.out
test ! -e Makefile
