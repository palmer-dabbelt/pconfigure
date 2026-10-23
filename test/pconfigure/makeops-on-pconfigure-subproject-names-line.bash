#include "harness_start.bash"

# The MAKEOPS twin of the CONFIGUREOPTS refusal: there is no make
# being run for a pconfigure subproject, so there is no command line
# to put a variable on.  The refusal has to say which line it is
# about, since a line like this is only ever written in a Configfile
# some way down the tree.
mkdir -p a/b

echo "SUBPROJECTS += a" > Configfile

cat >a/Configfile <<EOF
SUBPROJECTS   += b
MAKEOPS       += ARCH=arm64
EOF

echo "" > a/b/Configfile

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    exit 1
fi
cat out
grep -q "MAKEOPS doesn't apply to a pconfigure subproject" out
grep -q "a/Configfile:2" out

# A plain "no" leaves the reader to work out what a pconfigure
# project says instead of a make variable, so the refusal says that
# too.
grep -q "say what this was for in 'a/b/Configfile', with a COMPILEOPTS" out

exit 0
