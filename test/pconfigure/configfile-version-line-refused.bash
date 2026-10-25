#include "harness_start.bash"

# VERSION and HELP are the commands "--version" and "--help" turn
# into, and the Configfile parser accepts them too.  In a Configfile
# they can't do anything: whether to print the version and stop is
# decided before any Configfile is read.  "VERSION = 1.2.0" reads like
# the project's own version, and it used to be thrown away without a
# word -- exit 0, and a Makefile with no trace of it.
#
# A command that is accepted and does nothing is what the house rule
# for HDRDIR covers: refuse it, naming the line, and say where it
# does mean something.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

cat >Configfile <<'END'
LANGUAGES += c
VERSION    = 1.2.0
BINARIES  += main
SOURCES   += main.c
END

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    exit 1
fi
cat out
test ! -e Makefile
grep -q "Configfile:2" out
grep -q -- "--version" out
