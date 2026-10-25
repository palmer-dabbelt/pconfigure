#include "harness_start.bash"

# The same invisible bytes at the front of a SOURCES value.  pconfigure
# used to accept the line and write a Makefile, and make then stopped
# on "No rule to make target 'src/main.c'" -- quoting, as far as
# anybody reading a terminal can tell, a file that's right there.  The
# manual's promise is an error on the line the bytes are on.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

printf 'LANGUAGES   += c\nBINARIES    += main\nSOURCES     += \xef\xbb\xbfmain.c\n' \
    > Configfile

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    exit 1
fi
cat out
grep -q "Configfile:3" out
test ! -e Makefile
