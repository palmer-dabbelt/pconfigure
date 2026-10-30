#include "harness_start.bash"

# The most ordinary edit there is: a source deleted from disk and its
# SOURCES line taken out in the same commit.  The Makefile make reads
# first still names the source and its pdeps fragment, so the reconfigure
# has to happen before anything asks for the missing file -- a "No rule
# to make target src/old.c" from the old Makefile would stop the very
# make that was about to stop needing it.

mkdir -p src

cat >Configfile <<'EOC'
AUTORECONFIGURE  = true
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
SOURCES         += old.c
EOC

echo 'int main(void) { return 0; }' > src/main.c
echo 'int old(void) { return 0; }' > src/old.c

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test -x bin/main

# The Makefile names the source before the edit, so the grep after it is
# known to be looking for something that was there.
grep -q 'src/old\.c' Makefile

sleep 1
rm src/old.c
sed -i.bak '/old\.c/d' Configfile

make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
grep -q "^PCONFIGURE$" second.log
if grep -q 'old\.c' Makefile
then
    exit 1
fi
test -x bin/main

make $MAKE_ARGS > third.log 2>&1 || { cat third.log; exit 1; }
grep -q "Nothing to be done" third.log
