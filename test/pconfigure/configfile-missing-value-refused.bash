#include "harness_start.bash"

# A line with an operator and nothing after it is refused for every
# command but CROSS_COMPILE, the one where "nothing" is an answer (the
# way a single target takes back a cross compiler the whole project
# was given).  Trailing whitespace doesn't make the value any less
# empty.  Both refusals name the line.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

printf 'LANGUAGES   += c\nBINARIES    += main\nSOURCES     +=\n' > Configfile
if $PTEST_BINARY $PCONFIGURE_ARGS >bare.out 2>&1
then
    exit 1
fi
cat bare.out
grep -q "Configfile:3" bare.out
test ! -e Makefile

printf 'LANGUAGES   += c\nBINARIES    += main\nSOURCES     +=  \t \n' > Configfile
if $PTEST_BINARY $PCONFIGURE_ARGS >trailing.out 2>&1
then
    exit 1
fi
cat trailing.out
grep -q "Configfile:3" trailing.out
test ! -e Makefile

# CROSS_COMPILE takes the empty value, in any case, and with trailing
# whitespace too.
printf 'LANGUAGES   += c\ncross_compile =  \nBINARIES    += main\nSOURCES     += main.c\n' > Configfile
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
./bin/main
