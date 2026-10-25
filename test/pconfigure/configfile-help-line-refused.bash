#include "harness_start.bash"

# The HELP half of configfile-version-line-refused.bash.  "HELP =
# true" in a Configfile doesn't print the help -- the Configfile is
# read after that question has been answered -- and it used to not
# complain either, so a line that can't do anything stayed in the
# file forever.  It's refused with its line, like any other command
# that is parsed and does nothing, and pointed at "--help".
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

cat >Configfile <<'END'
LANGUAGES += c
BINARIES  += main
SOURCES   += main.c
HELP       = true
END

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    exit 1
fi
cat out
test ! -e Makefile
grep -q "Configfile:4" out
grep -q -- "--help" out
