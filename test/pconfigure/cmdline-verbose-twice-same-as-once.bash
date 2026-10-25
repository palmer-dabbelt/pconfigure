#include "harness_start.bash"

# --verbose is a switch, not a count: given twice -- once from an alias
# and once typed -- it writes the same Makefile it writes given once,
# but for the recorded command line, which is kept as it was typed.
mkdir -p src
echo 'int main(void) { return 0; }' > src/hello.c
cat >Configfile <<'EOF'
LANGUAGES += c
BINARIES  += hello
SOURCES   += hello.c
EOF

$PTEST_BINARY --verbose
grep -v '^PCONFIGURE_ARGS' Makefile > once.mk

# Once is enough to take effect -- the recipes lose their '@' -- so the
# comparison below is between two verbose Makefiles, not two quiet ones
# that would match whatever --verbose did.
grep -q "$(printf '^\t')mkdir -p" once.mk
if grep -q "$(printf '^\t')@" once.mk
then
    exit 1
fi

$PTEST_BINARY --verbose --verbose
grep -q '^PCONFIGURE_ARGS ?= --verbose --verbose$' Makefile
grep -v '^PCONFIGURE_ARGS' Makefile > twice.mk

diff -u once.mk twice.mk
