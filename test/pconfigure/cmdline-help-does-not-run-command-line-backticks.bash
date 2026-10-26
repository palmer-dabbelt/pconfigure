#include "harness_start.bash"

# --help promises to print the option list and touch nothing else, and
# the Configfile lines given beside it on the command line are part of
# what it shouldn't act on: their backticks are commands that run while
# configuring, and asking for help is not asking to configure.  A
# backtick that leaves a file behind shows whether it ran.
echo 'LANGUAGES += c' > Configfile

$PTEST_BINARY 'COMPILEOPTS += `touch ran-by-help`' --help > help.out 2>&1 || {
    cat help.out
    exit 1
}
cat help.out
grep -q "^usage: pconfigure" help.out
test ! -e ran-by-help
test ! -e Makefile
