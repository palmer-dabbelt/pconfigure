#include "harness_start.bash"

# A mistake in a subproject's Configfile is reported against that file,
# by the path pconfigure was run from: in a build of several projects
# "Configfile:1" alone is a line in any of them.  Pinned two levels
# down, and both ways round -- from the top the file is "a/b/Configfile",
# and from inside "a" it is "b/Configfile".
mkdir -p a/b

echo "SUBPROJECTS += a" > Configfile
echo "SUBPROJECTS += b" > a/Configfile
echo "SUBPROJECTS += ." > a/b/Configfile

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    exit 1
fi
cat out
grep -q "SUBPROJECTS can't point at the project itself" out
grep -q "a/b/Configfile:1 'SUBPROJECTS += \.'" out
test ! -e Makefile
test ! -e a/obj/Makefile.a

if (cd a && $PTEST_BINARY $PCONFIGURE_ARGS) > inside.out 2>&1
then
    exit 1
fi
cat inside.out
grep -q "b/Configfile:1 'SUBPROJECTS += \.'" inside.out
if grep -q "a/b/Configfile" inside.out
then
    exit 1
fi

exit 0
