#include "harness_start.bash"

# An executable CONFIG is a Configfile whose lines come out of a
# program, and the program is the file a person edits.  Under
# AUTORECONFIGURE that file is one of the names the reconfigure rule
# watches, so changing what the script prints -- here, a second
# binary -- is picked up by a plain make.

export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src Configfiles

cat >Configfile <<'EOF'
AUTORECONFIGURE  = true
LANGUAGES       += c
CONFIG          += targets
EOF

cat >Configfiles/targets <<'EOF'
#!/bin/bash
echo "BINARIES += one"
echo "SOURCES  += one.c"
EOF
chmod +x Configfiles/targets

echo 'int main(void) { return 0; }' > src/one.c
echo 'int main(void) { return 0; }' > src/two.c

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test -x bin/one
test ! -e bin/two
grep -q '\$(wildcard Configfiles/targets)' Makefile

sleep 1
cat >>Configfiles/targets <<'EOF'
echo "BINARIES += two"
echo "SOURCES  += two.c"
EOF

make $MAKE_ARGS > second.log 2>&1
cat second.log
grep -q "^PCONFIGURE$" second.log
test -x bin/two

# And once is enough.  The script is a prerequisite like any
# Configfile, so a reconfigure that left it newer than the Makefile
# would go on running on every make after this one.
make $MAKE_ARGS > third.log 2>&1
cat third.log
grep -q "Nothing to be done" third.log
if grep -q "^PCONFIGURE$" third.log
then
    exit 1
fi

exit 0
