#include "harness_start.bash"

# A Configfile edit that does not parse stops the reconfigure, and so
# the make, with the error pointing at the line.  What it must not do
# is take the Makefile with it: the old one stays exactly as it was,
# so the next make tries again rather than finding nothing to read,
# and fixing the line is all it takes to get going.

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
cp Makefile Makefile.before

sleep 1
echo "NOT_A_COMMAND   += x" >> Configfile

if make $MAKE_ARGS > second.log 2>&1
then
    cat second.log
    exit 1
fi
cat second.log
grep -q "Configfile:5" second.log
cmp Makefile Makefile.before

# Still broken, still says so, rather than having quietly given up.
if make $MAKE_ARGS > third.log 2>&1
then
    cat third.log
    exit 1
fi
cat third.log
grep -q "Configfile:5" third.log

sleep 1
sed -i '$d' Configfile
cat >>Configfile <<'EOF'
BINARIES        += other
SOURCES         += other.c
EOF

make $MAKE_ARGS > fourth.log 2>&1
cat fourth.log
grep -q "^PCONFIGURE$" fourth.log
test -x bin/other

exit 0
