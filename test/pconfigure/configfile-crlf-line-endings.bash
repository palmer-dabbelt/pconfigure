#include "harness_start.bash"

# A Configfile saved by an editor that ends lines with CRLF is still a
# Configfile: the '\r' is whitespace, and trailing whitespace is
# nothing.  It has to stay nothing all the way through -- a '\r' left
# on the end of a value becomes part of a file name in the Makefile,
# where it is invisible on a terminal and fatal to make.
#
# Every kind of line gets a CRLF here: commands, a comment, a blank
# line, and a line with a backtick in it, since that last one is run
# through a shell and a shell does not think '\r' is whitespace.
mkdir -p src
cat >src/main.c <<'EOF'
#include <string.h>
int main(void) { return strcmp(GREETING, "hello"); }
EOF

printf '%s\r\n' \
    'LANGUAGES   += c' \
    '' \
    '# a comment, also with a CRLF' \
    'BINARIES    += main' \
    'COMPILEOPTS += -DGREETING=\"`echo hello`\"' \
    'SOURCES     += main.c' \
    > Configfile

$PTEST_BINARY $PCONFIGURE_ARGS
if grep -q $'\r' Makefile
then
    echo "a carriage return made it into the Makefile" >&2
    exit 1
fi

make $MAKE_ARGS
./bin/main
