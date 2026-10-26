#include "harness_start.bash"

# A CONFIG_DEPS reaches the Makefile inside a "$(wildcard ...)", which
# has a ':', ';', '|' or glob character taken care of but not a
# parenthesis.  make counts parentheses to find where a function call
# ends, so the ')' in 'notes)1.txt' closes the $(wildcard early and
# what is left, '1.txt)', becomes a prerequisite of the Makefile that
# nothing makes: every make stops with "No rule to make target".  A
# ')' is a legal character in a file name and does nothing special on
# a rule line, so the file should be watched like any other.

mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c
echo 1 > 'notes)1.txt'
cat >Configfile <<'EOC'
AUTORECONFIGURE  = true
CONFIG_DEPS     += notes)1.txt
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
EOC

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

# Unchanged, it reconfigures nothing.
make $MAKE_ARGS > first.log 2>&1 || { cat first.log; exit 1; }
cat first.log
if grep -q PCONFIGURE first.log
then
    exit 1
fi

sleep 1
echo 2 >> 'notes)1.txt'
make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
grep -q PCONFIGURE second.log
