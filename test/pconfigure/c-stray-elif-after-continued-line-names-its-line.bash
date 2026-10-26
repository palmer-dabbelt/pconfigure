#include "harness_start.bash"

# The scan's own complaints point at a line too, and count lines the
# same way: a backslash-continued line counted once however many lines
# it took up.  The stray "#elif" here is on line 4 of main.c, after a
# macro written over three, and was reported on line 2.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += main
SOURCES     += main.c
EOF

printf '%s\n' \
    '#define SUM(a, b) \' \
    '    ((a) + \' \
    '     (b))' \
    '#elif 1' \
    'int main(void) { return SUM(0, 0); }' > src/main.c

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    cat out
    exit 1
fi
cat out

grep -q "src/main.c:4: '#elif 1'" out
