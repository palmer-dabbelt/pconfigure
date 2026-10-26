#include "harness_start.bash"

# A Configfile line given on the command line does what it would at
# the top of the first file read, and --srcpath is documented as the
# same as writing SRCPATH there.  So 'SRCPATH = ..' typed as a line and
# --srcpath .. typed as an option configure the same build: the
# Makefiles agree apart from the options they record.
mkdir -p checkout/src
echo 'int main(void) { return 0; }' > checkout/src/hello.c
cat >checkout/Configfile <<'EOF2'
LANGUAGES += c
BINARIES  += hello
SOURCES   += hello.c
EOF2
mkdir checkout/build
cd checkout/build

$PTEST_BINARY --srcpath ..
grep -v '^PCONFIGURE_ARGS' Makefile > option.mk
rm -rf Makefile obj

$PTEST_BINARY 'SRCPATH = ..'
grep -q "^PCONFIGURE_ARGS ?= 'SRCPATH = \.\.'$" Makefile
grep -v '^PCONFIGURE_ARGS' Makefile > line.mk

diff -u option.mk line.mk
make
./bin/hello
