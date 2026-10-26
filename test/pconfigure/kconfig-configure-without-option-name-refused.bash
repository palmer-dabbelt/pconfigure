#include "harness_start.bash"

# "--configure CONFIG_FOO=y" sets one option on top of the defconfig.
# One written without a name -- "--configure =y", which is what a line
# gets when the name was simply deleted -- became "scripts/config
# --file .config --enable ''" in the recipe, and the kernel's
# scripts/config pastes "CONFIG_" in front of whatever name it gets:
# that writes a "CONFIG_=y" that Kconfig throws away with a warning, so
# the option somebody meant is never set and nothing said the line was
# wrong.  It is refused at the line.  A name without the "CONFIG_" is
# one scripts/config takes, and is still taken.
mkdir -p sub/scripts

cat >sub/Kconfig <<'EOF2'
config BASE
	bool "base"
	default y
EOF2
echo "all:" > sub/Makefile

cat >sub/scripts/config <<'EOF2'
#!/bin/sh
exit 0
EOF2
chmod +x sub/scripts/config

cat >Configfile <<'EOF2'
BUILD_SYSTEMS += kconfig
SUBPROJECTS   += sub
CONFIGUREOPTS += --configure =y
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    cat out
    exit 1
fi
cat out
grep -q "Configfile:3" out
grep -qF "'--configure =y' has no name in front of its '='" out
grep -qF "it should look like '--configure CONFIG_FOO=y'" out
test ! -e Makefile

cat >Configfile <<'EOF2'
BUILD_SYSTEMS += kconfig
SUBPROJECTS   += sub
CONFIGUREOPTS += --configure BASE=n
EOF2
$PTEST_BINARY $PCONFIGURE_ARGS

exit 0
