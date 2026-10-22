#include "harness_start.bash"

# A file whose last line has no newline after it is common -- plenty of
# editors and every "printf > Configfile" leave one -- and the last
# line is as much a part of the file as any other.  Here it's the
# SOURCES that gives the binary its main(), so a reader that dropped an
# unterminated last line would leave a binary with nothing in it.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

printf 'LANGUAGES   += c\n\nBINARIES    += main\nSOURCES     += main.c' \
    > Configfile
test "$(tail -c 1 Configfile)" = "c"

$PTEST_BINARY $PCONFIGURE_ARGS
grep -q "src/main.c" Makefile
make $MAKE_ARGS
./bin/main

# And a CONFIG pulled in from another file gets the same treatment, so
# a binary declared in the last line of one and filled in by the next
# file still works.
rm -rf bin obj Makefile
printf 'LANGUAGES   += c\nCONFIG      += extra.conf\nSOURCES     += main.c\n' \
    > Configfile
mkdir -p Configfiles
printf 'BINARIES    += other' > Configfiles/extra.conf

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
./bin/other
