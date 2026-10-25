#include "harness_start.bash"

# A file saved with classic Mac line endings -- a bare carriage return
# and no newline -- is one line as far as getline() is concerned, and
# with the CRs read as the white space they are, the whole file comes
# out as one long LANGUAGES.  That has to stop the configure rather
# than write a Makefile, and the refusal quotes the line so that the
# run-together commands are there to see.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

printf 'LANGUAGES   += c\rBINARIES    += main\rSOURCES     += main.c\r' \
    > Configfile

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    exit 1
fi
cat out
grep -q "Configfile:1" out
grep -q "BINARIES += main" out
test ! -e Makefile
