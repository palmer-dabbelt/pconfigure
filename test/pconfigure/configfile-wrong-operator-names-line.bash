#include "harness_start.bash"

# A fatal error points at the Configfile line that caused it.  Using
# the wrong operator is the commonest mistake a Configfile has -- "="
# where the command only appends, "+=" where it only replaces -- and
# in a project with Configfiles/local, Configfile.local, Configfiles/
# main, Configfile and every CONFIG they pull in, "Command SOURCES only
# supports '+='" alone leaves the reader to grep for which of the
# dozens of SOURCES lines it was.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

# A command that only appends, given an '='.
cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += main
SOURCES      = main.c
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS >append.out 2>&1
then
    exit 1
fi
cat append.out
grep -q "Command SOURCES only supports '+='" append.out
grep -q "Configfile:4" append.out
grep -q "write 'SOURCES += main.c'" append.out
test ! -e Makefile

# A command that only replaces, given a '+='.
cat >Configfile <<'EOF'
LANGUAGES   += c

LIBDIR      += lib
BINARIES    += main
SOURCES     += main.c
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS >replace.out 2>&1
then
    exit 1
fi
cat replace.out
grep -q "Command LIBDIR only supports '='" replace.out
grep -q "Configfile:3" replace.out
grep -q "write 'LIBDIR = lib'" replace.out
test ! -e Makefile

# The rewrite is spelled the way the line was written, not the way
# pconfigure processes it: a HEADERSRC is handled as a HEADERS, and a
# TESTS with a name in brackets as a plain TESTS, and pasting either of
# those back would change what the line means.
touch src/main.h
mkdir -p test
echo 'int main(void) { return 0; }' > test/net.c

cat >Configfile <<'EOF2'
LANGUAGES   += c

BINARIES    += main
SOURCES     += main.c
HEADERSRC    = main.h
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS >headersrc.out 2>&1
then
    exit 1
fi
cat headersrc.out
grep -q "Configfile:5" headersrc.out
grep -q "write 'HEADERSRC += main.h'" headersrc.out
test ! -e Makefile

cat >Configfile <<'EOF2'
LANGUAGES   += c

BINARIES    += main
SOURCES     += main.c
TESTS[net]   = net.c
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS >tests.out 2>&1
then
    exit 1
fi
cat tests.out
grep -q "Configfile:5" tests.out
grep -q "write 'TESTS\[net\] += net.c'" tests.out
test ! -e Makefile
