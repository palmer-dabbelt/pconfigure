#include "harness_start.bash"

# A MAKEOPS without an '=' is a goal rather than a variable, and is
# refused.  With vendored trees under subprojects, which Configfile
# the line is in is the part of that refusal somebody needs, so it has
# to name the line along with the spelling it wanted.
mkdir -p a/k

echo "SUBPROJECTS += a" > Configfile

cat >a/Configfile <<EOF
BUILD_SYSTEMS += kconfig

SUBPROJECTS   += k
MAKEOPS       += V
EOF

cat >a/k/Kconfig <<'EOF'
config X
	bool "x"
EOF
echo "all:" > a/k/Makefile

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    exit 1
fi
cat out
grep -q "MAKEOPS 'V' has no value" out
grep -q "a/Configfile:4" out
grep -q "it should look like 'MAKEOPS += ARCH=arm64'" out

# kbuild's "--make-var" is the same variable written as an option, and
# is refused by the same check.  The line to point at is then the
# CONFIGUREOPTS that wrote it, not some MAKEOPS that isn't there.
cat >a/Configfile <<EOF
BUILD_SYSTEMS += kconfig

SUBPROJECTS   += k
CONFIGUREOPTS += --make-var V
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    exit 1
fi
cat out
grep -q "MAKEOPS 'V' has no value" out
grep -q "a/Configfile:4 'CONFIGUREOPTS += --make-var V'" out

exit 0
