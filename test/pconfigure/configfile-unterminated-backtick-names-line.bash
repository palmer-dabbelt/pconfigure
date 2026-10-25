#include "harness_start.bash"

# A backtick that never closes is refused, and configfile-backticks.bash
# already pins that much.  What it doesn't pin is where: the refusal
# quotes the line's text and nothing else, and in a tree with a
# Configfile, a Configfiles/main and a handful of CONFIGs the text of
# a SOURCES line is no help finding it.  The house rule for a fatal
# error is that it names the Configfile line, so this asks for the
# file and the number -- the third line, so that a message naming the
# first can't pass by accident.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

cat >Configfile <<'END'
LANGUAGES += c
BINARIES  += main
SOURCES   += `echo main.c
END

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    exit 1
fi
cat out
test ! -e Makefile
grep -q "unterminated" out
grep -q "Configfile:3" out
