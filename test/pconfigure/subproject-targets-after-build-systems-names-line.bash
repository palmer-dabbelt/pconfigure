#include "harness_start.bash"

# A SUBPROJECT_TARGETS written straight after a BUILD_SYSTEMS has no
# tree to belong to, and is refused.  The refusal has to name the
# line as well as the path: a BUILD_SYSTEMS is most often written in a
# subproject's Configfile, which nobody at the top of the build has
# open.
mkdir -p a

echo "SUBPROJECTS += a" > Configfile

cat >a/Configfile <<EOF
BUILD_SYSTEMS      += kconfig
SUBPROJECT_TARGETS += arch/arm64/boot/Image
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    exit 1
fi
cat out
grep -q "SUBPROJECT_TARGETS needs a SUBPROJECTS above it" out
grep -q "a/Configfile:2" out

exit 0
