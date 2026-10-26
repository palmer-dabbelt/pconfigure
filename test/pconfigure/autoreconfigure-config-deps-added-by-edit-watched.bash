#include "harness_start.bash"

# A CONFIG_DEPS line that arrives by an edit rather than being there
# from the first configure.  The edit is a Configfile change, so it
# reconfigures; the Makefile that writes then watches the directory, so
# the next file to appear in it reconfigures again and is picked up.
# Each step is a plain "make".

mkdir -p src tests Configfiles

cat >Configfile <<'EOC'
AUTORECONFIGURE  = true
LANGUAGES       += c
CONFIG          += programs
EOC

cat >Configfiles/programs <<'EOC'
#!/bin/bash
for f in tests/*; do
    [ -e "$f" ] || continue
    echo "BINARIES += ${f##*/}"
    echo "SOURCES  += hello.c"
done
EOC
chmod +x Configfiles/programs

echo 'int main(void) { return 0; }' > src/hello.c
touch tests/first

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test -x bin/first
if grep -q '\$(wildcard tests)' Makefile
then
    exit 1
fi

sleep 1
echo 'CONFIG_DEPS     += tests' >> Configfile
make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
grep -q "^PCONFIGURE$" second.log
grep -q '\$(wildcard tests)' Makefile

sleep 1
touch tests/second
make $MAKE_ARGS > third.log 2>&1 || { cat third.log; exit 1; }
cat third.log
grep -q "^PCONFIGURE$" third.log
test -x bin/second

make $MAKE_ARGS > fourth.log 2>&1 || { cat fourth.log; exit 1; }
grep -q "Nothing to be done" fourth.log
