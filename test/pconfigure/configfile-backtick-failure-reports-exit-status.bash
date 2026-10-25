#include "harness_start.bash"

# A backtick whose command fails used to be reported on stderr as the
# command followed by what pclose() returned, which is a wait status
# rather than an exit status: a command that exited with 3 was
# reported as "768".  That is not a number the command printed or a
# shell would show.  What gets said is the exit status, next to the
# Configfile line the command came from.
mkdir -p src

cat >Configfile <<EOF
LANGUAGES   += c

BINARIES    += test
COMPILEOPTS += \`exit 3\`
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
if grep -q "768" stderr
then
    echo "reported the wait status, not the exit status" >&2
    exit 1
fi
grep -q "status 3" stderr
grep -q "Configfile:4" stderr

exit 0
