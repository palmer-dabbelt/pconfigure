#include "harness_start.bash"

# A refused "#pconfigure" directive in a C test is reported at its
# file and line, which is what someone has to go and edit.  A C file is
# read with its backslash-continued lines joined, and the line counter
# moved once per joined line rather than once per line in the file --
# so after a macro continued over three lines the directive on line 4
# was reported as line 2, a line holding half a macro.
#
# Written with printf, since a '#' in the first column of this file is
# a directive for this file.

mkdir -p src test/main

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += main
SOURCES     += main.c
TESTSRC     += t.c
EOF

echo 'int main(void) { return 0; }' > src/main.c

printf '%s\n' \
    '#define SUM(a, b) \' \
    '    ((a) + \' \
    '     (b))' \
    '#pconfigure BOGUS += x' \
    'int main(void) { return SUM(0, 0); }' > test/main/t.c

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    cat out
    exit 1
fi
cat out

grep -q "test/main/t.c:4" out
