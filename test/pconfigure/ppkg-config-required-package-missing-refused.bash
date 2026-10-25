#include "harness_start.bash"

# ppkg-config's "--optional" exists to say "carry on if the package
# isn't there", which makes leaving it off a way of saying the
# package is required -- and ppkg-config does exit non-zero for one
# that's missing.  pconfigure used to print the command along with
# the raw value pclose() returned and then carry on: the line added
# nothing, the Makefile was written, and pconfigure exited 0, so the
# person found out at compile time from a missing header with no
# pointer back to the line that asked.
#
# A required dependency that is missing is the one thing a configure
# step is for, so the run stops and names the Configfile line.
mkdir -p src

cat >Configfile <<EOF
LANGUAGES   += c

BINARIES    += test
COMPILEOPTS += \`ppkg-config pconfigure-no-such-package-anywhere --cflags\`
SOURCES     += test.c
EOF

cat >src/test.c <<EOF
int main(void) { return 0; }
EOF

set +e
$PTEST_BINARY $PCONFIGURE_ARGS 2>stderr
status="$?"
set -e
cat stderr

test "$status" != "0"
test ! -e Makefile
grep -q "Configfile:4" stderr

# The same package asked about with --optional is not refused: that is
# what --optional is for.
cat >Configfile <<EOF
LANGUAGES   += c

BINARIES    += test
COMPILEOPTS += \`ppkg-config --optional pconfigure-no-such-package-anywhere --cflags\`
SOURCES     += test.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
test -e Makefile

exit 0
