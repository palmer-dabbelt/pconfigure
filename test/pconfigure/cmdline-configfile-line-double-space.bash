#include "harness_start.bash"

# A word on the command line that isn't an option is a Configfile line,
# and the manual says giving one there "does exactly what writing that
# command at the top of the first file read would do".  In a file the
# line is tidied first, so a run of spaces between the command and its
# operator is just the space between two words.  On the command line
# it isn't: the split finds an empty word where the operator should be
# and the complaint is about an operator '' -- with advice to write
# 'LANGUAGES += += c', which is the line made worse.
mkdir -p src
echo 'int main(void) { return 0; }' > src/hello.c

cat >Configfile <<'EOF'
BINARIES += hello
SOURCES  += hello.c
EOF

# The same line, as a Configfile would have it, works.
echo 'LANGUAGES  +=  c' > Configfile.local
$PTEST_BINARY
rm -f Configfile.local Makefile

if ! $PTEST_BINARY 'LANGUAGES  +=  c' > out 2>&1
then
    cat out
    exit 1
fi
cat out

make $MAKE_ARGS
test -x bin/hello
