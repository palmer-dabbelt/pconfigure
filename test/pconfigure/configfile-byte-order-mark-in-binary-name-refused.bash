#include "harness_start.bash"

# The manual says a UTF-8 byte order mark is forgiven only at the very
# start of the file, and that anywhere else the bytes are an error on
# the line they're on.  One pasted into the middle of a value was let
# through, though: this builds a program whose name starts with an
# invisible character, so "bin/main" on a terminal is not the file
# that "./bin/main" runs.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

printf 'LANGUAGES   += c\nBINARIES    += \xef\xbb\xbfmain\nSOURCES     += main.c\n' \
    > Configfile

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    exit 1
fi
cat out
grep -q "Configfile:2" out
test ! -e Makefile
