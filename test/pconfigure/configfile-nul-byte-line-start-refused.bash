#include "harness_start.bash"

# A NUL at the very start of a line made the whole line read as empty,
# so a command that is plainly there in the file -- a second binary,
# here -- was skipped as though it were a blank line.  That's the
# shape every line but the first of a UTF-16 Configfile has, too.  A
# NUL byte is refused, on the line it's on.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c
echo 'int main(void) { return 0; }' > src/other.c

printf 'LANGUAGES   += c\nBINARIES    += main\nSOURCES     += main.c\n\000BINARIES    += other\nSOURCES     += other.c\n' \
    > Configfile
od -c Configfile

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    exit 1
fi
cat out
grep -q "Configfile:4" out
test ! -e Makefile
