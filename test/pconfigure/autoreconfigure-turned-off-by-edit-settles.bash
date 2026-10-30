#include "harness_start.bash"

# Turning AUTORECONFIGURE off is itself a Configfile edit, and the rule
# that notices it is the one being turned off.  That works out: the
# old Makefile still has the rule, so the edit reconfigures once, and
# what it writes has no rule -- so later edits are left for somebody to
# ask about, the way every project without the line behaves.  In
# between the build has to go on working, even though the object
# directory still holds the fragments the old Makefile included.

export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src

cat >Configfile <<'EOF'
AUTORECONFIGURE  = true
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
EOF

echo 'int main(void) { return 0; }' > src/main.c
echo 'int main(void) { return 0; }' > src/other.c

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
grep -q '^Makefile:' Makefile

sleep 1
sed -i.bak 's/^AUTORECONFIGURE .*/AUTORECONFIGURE  = false/' Configfile

make $MAKE_ARGS > second.log 2>&1
cat second.log
grep -q "^PCONFIGURE$" second.log
if grep -q '^Makefile:' Makefile
then
    exit 1
fi
test -x bin/main

make $MAKE_ARGS > third.log 2>&1
cat third.log
# Make prints "Nothing to be done" after a reconfigure too, so settling
# means pconfigure didn't run again as well.
if grep -q "^PCONFIGURE$" third.log
then
    exit 1
fi
grep -q "Nothing to be done" third.log

# Now an edit is somebody else's business.
sleep 1
cat >>Configfile <<'EOF'
BINARIES        += other
SOURCES         += other.c
EOF
make $MAKE_ARGS > fourth.log 2>&1
cat fourth.log
if grep -q "^PCONFIGURE$" fourth.log
then
    exit 1
fi
test ! -e bin/other

exit 0
