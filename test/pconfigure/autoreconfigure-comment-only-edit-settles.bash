#include "harness_start.bash"

# An edit that changes nothing a Makefile says -- a comment -- still
# makes the Configfile newer than the Makefile, so it reconfigures once.
# What matters is that it is once: the Makefile is rewritten whether or
# not its contents changed, and if it ever stopped being, a comment
# would leave the Configfile newer than its target for good and every
# make after would reconfigure again.  Nothing is recompiled or
# relinked either, since the configuration it wrote is the same one.

export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src

cat >Configfile <<'EOF'
AUTORECONFIGURE  = true
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
EOF

echo 'int main(void) { return 0; }' > src/main.c

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

sleep 1
echo "# nothing to see here" >> Configfile

make $MAKE_ARGS > second.log 2>&1
cat second.log
test "$(grep -c "^PCONFIGURE$" second.log)" -eq 1
if grep -qE "^(CC|LD)	" second.log
then
    exit 1
fi

make $MAKE_ARGS > third.log 2>&1
cat third.log
grep -q "Nothing to be done" third.log
if grep -q "^PCONFIGURE$" third.log
then
    exit 1
fi

exit 0
