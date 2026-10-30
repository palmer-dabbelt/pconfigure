#include "harness_start.bash"

# A SRCPATH goes on the front of every source path the way a SRCDIR
# does, one level further out, and those paths reach the compile line
# as bare words: a source tree at "-sp" compiles with
# "-c -sp/src/main.c", which the compiler takes for an option and
# answers with "no input files".  It used to configure without a word
# and fail inside make, so it is refused while configuring, from a
# Configfile and from the command line alike, and the "./-sp" the
# refusal suggests is checked to really build.
mkdir -p ./-sp/src
echo 'int main(void) { return 0; }' > ./-sp/src/main.c

cat >Configfile <<'EOF2'
LANGUAGES += c
SRCPATH    = -sp
BINARIES  += main
SOURCES   += main.c
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
then
    cat configure.out
    exit 1
fi
cat configure.out
grep -qF "Configfile:2 'SRCPATH = -sp'" configure.out
grep -qF "SRCPATH names a directory starting with a '-'" configure.out
grep -qF "'SRCPATH = ./-sp'" configure.out
test ! -e Makefile

sed -i.bak 's@^SRCPATH .*@SRCPATH    = ./-sp@' Configfile
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
./bin/main

# The same tree named by '--srcpath', which reaches the same check by
# the other door, with the Configfile moved into the tree as that
# option expects.
rm -rf Makefile Configfile obj bin
cat >./-sp/Configfile <<'EOF2'
LANGUAGES += c
BINARIES  += main
SOURCES   += main.c
EOF2

if $PTEST_BINARY --srcpath -sp > configure.out 2>&1
then
    cat configure.out
    exit 1
fi
cat configure.out
grep -qF -- "--srcpath -sp" configure.out
grep -qF "SRCPATH names a directory starting with a '-'" configure.out
grep -qF -- "'--srcpath ./-sp'" configure.out
test ! -e Makefile

$PTEST_BINARY --srcpath ./-sp
make $MAKE_ARGS
./bin/main
