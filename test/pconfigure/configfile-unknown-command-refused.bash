#include "harness_start.bash"

# A misspelled command is the most ordinary mistake there is, and a
# misspelled one has to stop the run rather than be passed over: a
# "SOURCE += main.c" that quietly did nothing would leave a binary
# without its main and a link error that says nothing about the
# Configfile.  The refusal names the line, and nothing is written.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += main
SOURCE      += main.c
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    exit 1
fi
cat out
grep -q "Configfile:4" out
grep -q "SOURCE " out
test ! -e Makefile

# An unknown command in a CONFIG'd file is refused the same way, and
# the file it's in is the one named.
cat >Configfile <<'EOF'
LANGUAGES   += c
CONFIG      += extra.conf
EOF
mkdir -p Configfiles
cat >Configfiles/extra.conf <<'EOF'
BINARIES    += main
SORCES      += main.c
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS >config.out 2>&1
then
    exit 1
fi
cat config.out
grep -q "extra.conf:2" config.out
test ! -e Makefile
