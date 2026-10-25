#include "harness_start.bash"

# "--cross-compile PREFIX" is how one tree is built for another machine
# without editing it.  Under AUTORECONFIGURE, the reconfigure a
# Configfile edit sets off has to keep that prefix: a build that goes
# back to the host compiler because somebody added a source mid-way
# links a program for the wrong machine, and says nothing about it.
#
# The prefix here names no real toolchain, because what is being
# checked is what the Makefile says rather than what it builds.

export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src

cat >Configfile <<'EOF'
AUTORECONFIGURE  = true
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
EOF

echo 'int main(void) { return 0; }' > src/main.c

$PTEST_BINARY $PCONFIGURE_ARGS --cross-compile pconfigure-test-
grep -q 'pconfigure-test-gcc' Makefile

# Nothing is built -- there is no such compiler -- so the reconfigure
# is asked for the way make would ask for it: by bringing the Makefile
# up to date after a Configfile became newer than it.
sleep 1
echo "# a comment" >> Configfile

make $MAKE_ARGS Makefile > second.log 2>&1 || true
cat second.log
grep -q "^PCONFIGURE$" second.log

grep -q 'pconfigure-test-gcc' Makefile

exit 0
