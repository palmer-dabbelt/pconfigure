#include "harness_start.bash"

# A command in backticks that fails is the usual way a Configfile
# finds out a package isn't installed: "pkg-config --cflags foo" exits
# non-zero and prints nothing on stdout.  pconfigure used to say the
# command and its raw wait status ("'false': 256") with no Configfile
# line, and then carry on and write a Makefile with the flags quietly
# missing.  The run stops now, and what it says points at the line --
# the third one, so that a message naming the first can't pass by
# accident.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

cat >Configfile <<'END'
LANGUAGES   += c
BINARIES    += main
COMPILEOPTS += `false`
SOURCES     += main.c
END

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    exit 1
fi
cat out
test ! -e Makefile
grep -q "false" out
grep -q "Configfile:3" out
