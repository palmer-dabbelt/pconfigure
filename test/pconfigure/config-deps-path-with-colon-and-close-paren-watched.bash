#include "harness_start.bash"

# A name with a ':' in it is not handed to the rule line as the bare
# result of its $(wildcard): the name itself is written as the last
# argument of a $(foreach), spelled for the rule line.  That argument
# is inside a call too, so a ')' in it would close the $(foreach) just
# as one in the $(wildcard) closes that, and the name has to be spelled
# for both at once.

mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c
echo 1 > 'notes:1)x.txt'
cat >Configfile <<'EOC'
AUTORECONFIGURE  = true
CONFIG_DEPS     += notes:1)x.txt
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
EOC

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

make $MAKE_ARGS > first.log 2>&1 || { cat first.log; exit 1; }
cat first.log
if grep -q PCONFIGURE first.log
then
    exit 1
fi

sleep 1
echo 2 >> 'notes:1)x.txt'
make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
grep -q PCONFIGURE second.log
