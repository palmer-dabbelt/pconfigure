#include "harness_start.bash"

# The same as a wrong operator in the Configfile, but in a file pulled
# in with CONFIG: the name of the file matters as much as the line
# number does, because "line 2" of which file is the whole question
# once a project has more than one of them.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

cat >Configfile <<'EOF'
LANGUAGES   += c
CONFIG      += extra.conf

BINARIES    += main
SOURCES     += main.c
EOF

mkdir -p Configfiles
cat >Configfiles/extra.conf <<'EOF'
# A comment, so the bad line isn't the first one.
PREFIX      += /opt/nowhere
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    exit 1
fi
cat out
grep -q "Command PREFIX only supports '='" out
grep -q "extra.conf:2" out
grep -q "write 'PREFIX = /opt/nowhere'" out
test ! -e Makefile
