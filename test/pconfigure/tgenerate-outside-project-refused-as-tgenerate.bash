#include "harness_start.bash"

# TGENERATE shares GENERATE's checks, and so its refusals.  Those have
# to name the command that was written: a refusal that said GENERATE
# about a line that says TGENERATE sends whoever reads it looking for
# a line that isn't in the Configfile, and an example to copy that
# would quietly move the script out of test/.

mkdir -p src test

cat >Configfile <<EOF
LANGUAGES  += c

TGENERATE  += ../gen.h

BINARIES   += app
SOURCES    += app.c
EOF

cat >src/app.c <<'EOF'
int main(void) { return 0; }
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS >configure.out 2>&1
then
    cat configure.out
    exit 1
fi
cat configure.out

grep -q "Configfile:3" configure.out
grep -q "error: TGENERATE names a file outside this project" configure.out
grep -q "'TGENERATE += gen.h'" configure.out
if grep -q "error: GENERATE" configure.out
then
    exit 1
fi
test ! -e Makefile

exit 0
