#include "harness_start.bash"

# A SUBPROJECT_TARGETS under a pconfigure subproject has nothing to
# wait for, and is refused.  The refusal has to name the line, since
# in a build of several projects the subproject it was written under
# could be any of them.
mkdir -p a/b

echo "SUBPROJECTS += a" > Configfile

cat >a/Configfile <<EOF
LANGUAGES          += c

SUBPROJECTS        += b
SUBPROJECT_TARGETS += lib/libb.so
EOF

echo "" > a/b/Configfile

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    exit 1
fi
cat out
grep -q "SUBPROJECT_TARGETS doesn't apply to a pconfigure subproject" out
grep -q "a/Configfile:4" out

# A file a pconfigure project builds is a target of this Makefile
# already, so what to write instead is nothing: the refusal says to
# name it directly and drop the line.
grep -q "name it where it is needed, and drop this line" out

exit 0
