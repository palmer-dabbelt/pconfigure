#include "harness_start.bash"

# The other side of refusing an absolute SUBPROJECTS and one that
# climbs out of the run: a path that only looks like it might.  Inside
# "a", "x/../b" passes through ".." on its way and ends up under "a"
# anyway, and "./c" and "d//" are just untidy ways of naming "c" and
# "d".  None of them leaves "a" -- nor starts with a '/' -- so all three
# are accepted whether pconfigure runs in "a" or at the top.
mkdir -p a/b a/c a/d

echo "SUBPROJECTS += a" > Configfile
cat >a/Configfile <<EOF2
SUBPROJECTS += x/../b
SUBPROJECTS += ./c
SUBPROJECTS += d//
EOF2
echo "" > a/b/Configfile
echo "" > a/c/Configfile
echo "" > a/d/Configfile

if ! (cd a && $PTEST_BINARY $PCONFIGURE_ARGS) > inside.out 2>&1
then
    cat inside.out
    exit 1
fi
cat inside.out

if ! $PTEST_BINARY $PCONFIGURE_ARGS > above.out 2>&1
then
    cat above.out
    exit 1
fi
cat above.out
test -e Makefile

exit 0
