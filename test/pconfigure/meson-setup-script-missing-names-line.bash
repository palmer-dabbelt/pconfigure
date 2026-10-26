#include "harness_start.bash"

# A '--setup-script' that names nothing in the tree can only be
# checked once the tree is bound, which is later than the option was
# read.  The diagnostic still owes the Configfile line that named the
# script: it is the line to fix, and "isn't a program in sub" says
# nothing about which line that was.
mkdir -p sub
touch sub/meson.build

cat >Configfile <<'EOF2'
BUILD_SYSTEMS += meson
SUBPROJECTS   += sub
CONFIGUREOPTS += --setup-script configure
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    exit 1
fi
cat out
grep -q "'--setup-script configure' isn't a program in sub" out
grep -q "Configfile:3" out

exit 0
