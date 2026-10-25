#include "harness_start.bash"

# The refusal of a run with no Configfile is about a run that would
# read nothing at all.  Configfile lines given on the command line are
# a project somebody described on purpose, with or without a file
# behind them, so a directory holding only sources still configures
# and builds when the lines that describe it are the arguments.
mkdir src
echo 'int main(void) { return 0; }' > src/hello.c

$PTEST_BINARY $PCONFIGURE_ARGS 'LANGUAGES += c' 'BINARIES += hello' \
    'SOURCES += hello.c'
make
./bin/hello
