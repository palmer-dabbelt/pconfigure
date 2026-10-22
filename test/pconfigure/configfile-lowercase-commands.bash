#include "harness_start.bash"

# Command names are matched without regard to case, which is the
# behaviour check_command_type() has always had.  A Configfile written
# in lower case, or with the odd command in mixed case, describes the
# same build as one written in capitals -- including the commands that
# carry a name in brackets, where only the command part is a command
# name and the name inside keeps its case.
mkdir -p src test/main
echo 'int main(void) { return 0; }' > src/main.c
echo true > test/main/quick.bash

cat >Configfile <<'EOF'
languages     += c
Languages     += bash

test_suites   += Fast

binaries      += main
Compileopts   += -DLOWER
sources       += main.c
testsrc[Fast] += quick.bash
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
grep -q -- "-DLOWER" Makefile

# The suite is the one the TEST_SUITES line named, in the case it was
# written in, and the test landed in it.
grep -q "^check-Fast: " Makefile
grep -q "^obj/check-suite-Fast-done: check/main/quick.bash$" Makefile

make $MAKE_ARGS
./bin/main
