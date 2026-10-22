#include "harness_start.bash"

# The refusal of a command written with the wrong operator has to name
# the file as well as the line.  In a build of several projects
# "Command LANGUAGES only supports '+='" is about every Configfile in
# the tree at once, and the one at fault here is two subprojects down,
# in a file nobody at the top has open.
mkdir -p a/b

echo "SUBPROJECTS += a" > Configfile
echo "SUBPROJECTS += b" > a/Configfile

cat >a/b/Configfile <<EOF
LANGUAGES += c
LANGUAGES  = c
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    exit 1
fi
cat out
grep -q "only supports '+='" out
grep -q "a/b/Configfile:2" out
grep -q "write 'LANGUAGES += c'" out
test ! -e Makefile

exit 0
