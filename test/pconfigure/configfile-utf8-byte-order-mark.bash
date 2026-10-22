#include "harness_start.bash"

# Windows editors have a habit of starting a UTF-8 file with a byte
# order mark, the three bytes EF BB BF, and the same editors end every
# line with a CRLF.  pconfigure reads the CRLF as the whitespace it is,
# and a byte order mark is no more a part of what was written than the
# CR is: it says how the file is encoded, not what's in it.  Reading it
# as the start of the first command name used to produce a complaint
# about a command that looked, on a terminal, exactly like LANGUAGES.
#
# Each file gets its own mark, since each one was saved on its own,
# so both of the Configfiles read by default start with one here.
mkdir -p src Configfiles
echo 'int main(void) { return 0; }' > src/main.c

printf '\xef\xbb\xbfLANGUAGES += c\r\n' > Configfiles/main
printf '\xef\xbb\xbfBINARIES += main\nSOURCES += main.c\n' > Configfile

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
./bin/main
