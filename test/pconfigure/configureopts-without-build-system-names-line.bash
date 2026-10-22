#include "harness_start.bash"

# A CONFIGUREOPTS or a MAKEOPS with nothing above it to land on has to
# be refused with the file and line, and with where the line belongs.
# A subproject's Configfile is where this usually happens -- the line
# was copied out of the parent's, where it sat under a SUBPROJECTS --
# so "needs a BUILD_SYSTEMS target" alone sends its reader to the one
# file that is fine.
mkdir -p a

echo "SUBPROJECTS += a" > Configfile

cat >a/Configfile <<EOF
LANGUAGES     += c

MAKEOPS       += ARCH=arm64
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    exit 1
fi
cat out
grep -q "MAKEOPS" out
grep -q "a/Configfile:3" out
grep -q "write it below the BUILD_SYSTEMS or SUBPROJECTS" out

# And the same for CONFIGUREOPTS, at the top this time.
cat >Configfile <<EOF
LANGUAGES     += c
CONFIGUREOPTS += --defconfig x
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    exit 1
fi
cat out
grep -q "CONFIGUREOPTS" out
grep -q "Configfile:2" out
grep -q "write it below the BUILD_SYSTEMS or SUBPROJECTS" out

exit 0
