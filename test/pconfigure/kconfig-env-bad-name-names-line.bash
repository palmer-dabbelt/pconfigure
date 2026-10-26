#include "harness_start.bash"

# An '--env' whose name a shell wouldn't read as a name is refused
# where it was written, rather than left to become a command at build
# time.  "Where it was written" is a Configfile line, so the refusal
# names it.
mkdir -p k
cat >k/Kconfig <<'EOF2'
config X
	bool "x"
EOF2
echo "all:" > k/Makefile

cat >Configfile <<'EOF2'
BUILD_SYSTEMS += kconfig
SUBPROJECTS   += k
CONFIGUREOPTS += --env 2FAST=yes
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    exit 1
fi
cat out
grep -q "'--env 2FAST=yes' doesn't start with a variable name" out
grep -q "Configfile:3" out

exit 0
