#include "harness_start.bash"

# Two BINARIES that come out in one place from different sources are
# refused while configuring, naming the second line, the way
# binaries-same-name-mismatched-recipe-says-which.bash checks for two
# lines spelled alike.  "./main" comes out in the same place as "main"
# -- bin/./main is bin/main -- but the name used to be used as written,
# so make was handed two different targets for one file, the pair got
# through, and two rules raced to write it: with both running, one
# "mv" found the other's temporary already gone, and whichever program
# landed last was the one bin/main held.
mkdir -p src
echo 'int main(void) { return 0; }' > src/a.c
echo 'int main(void) { return 1; }' > src/b.c

cat >Configfile <<EOF
LANGUAGES += c

BINARIES  += main
SOURCES   += a.c

BINARIES  += ./main
SOURCES   += b.c
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
then
    cat configure.out
    grep -n "^bin/" Makefile
    exit 1
fi
cat configure.out
grep -qF "'bin/main' was already asked for" configure.out
grep -qF "Configfile:6 'BINARIES += ./main'" configure.out
