#include "harness_start.bash"

# The top names "a/b" directly and never names "a", so "a" is just a
# directory in this run, not a project.  "SUBPROJECTS += .." in a/b
# still names a directory wrapped around the project that wrote it,
# and is refused against a/b's line.  The message must not claim that
# "a" already has a/b as a subproject or that the line closes a cycle
# through it: nothing here makes "a" a project, so it says only what
# is true of every such line, that the directory contains this one.
mkdir -p a/b

echo "SUBPROJECTS += a/b" > Configfile
echo "SUBPROJECTS += .." > a/b/Configfile

if $PTEST_BINARY $PCONFIGURE_ARGS > above.out 2>&1
then
    cat above.out
    exit 1
fi
cat above.out
grep -q "SUBPROJECTS can't point at a directory that contains it" above.out
grep -q "a/b/Configfile:1 'SUBPROJECTS += \.\.'" above.out
grep -q "'\.\.' resolves to 'a/', which contains this project's directory" above.out
grep -q "remove the line" above.out
if grep -q "cycle" above.out
then
    exit 1
fi
test ! -e Makefile

exit 0
