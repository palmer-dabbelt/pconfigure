#include "harness_start.bash"

# A '--configure-flag' that isn't a flag is refused and told to be a
# '--configure-var'.  That advice is only half of what a fatal error
# owes: it also has to point at the Configfile line it is about.
mkdir -p sub
touch sub/configure.ac

cat >Configfile <<'EOF2'
BUILD_SYSTEMS += autotools
SUBPROJECTS   += sub

CONFIGUREOPTS += --configure-flag CFLAGS=-O2
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    exit 1
fi
cat out
grep -q "'--configure-flag CFLAGS=-O2' isn't a flag" out
grep -q "Configfile:4" out

exit 0
