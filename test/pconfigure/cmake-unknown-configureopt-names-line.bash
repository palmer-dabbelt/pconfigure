#include "harness_start.bash"

# An option cmake doesn't know is refused with the list of the ones it
# does.  It is a typo in a Configfile, so the Configfile line is what
# somebody needs pointed at -- here inside a subproject, where the
# option's text says nothing about which of two Configfiles holds it.
mkdir -p a/k

echo "SUBPROJECTS += a" > Configfile

cat >a/Configfile <<'EOF2'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += k
CONFIGUREOPTS += --build-typo Release
EOF2

echo 'project(k NONE)' > a/k/CMakeLists.txt

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    exit 1
fi
cat out
grep -q "unknown CONFIGUREOPTS '--build-typo Release'" out
grep -q "a/Configfile:4" out

exit 0
