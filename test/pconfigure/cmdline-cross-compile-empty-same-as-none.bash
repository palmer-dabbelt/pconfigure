#include "harness_start.bash"

# A Configfile can't write "CROSS_COMPILE =" with nothing after it, but
# "--cross-compile ''" reaches the same command with an empty value --
# the shape a wrapper script produces from an unset $CROSS.  That is
# taken as no prefix at all: the Makefile is the native one, word for
# word, apart from the options it records for the next reconfigure.
mkdir -p src
echo 'int main(void) { return 0; }' > src/hello.c
cat >Configfile <<'EOF2'
LANGUAGES += c
BINARIES  += hello
SOURCES   += hello.c
EOF2

$PTEST_BINARY
grep -v '^PCONFIGURE_ARGS' Makefile > native.mk

$PTEST_BINARY --cross-compile ''
grep -q "^PCONFIGURE_ARGS ?= --cross-compile ''$" Makefile
grep -v '^PCONFIGURE_ARGS' Makefile > empty.mk

diff -u native.mk empty.mk
make
./bin/hello
