#include "harness_start.bash"

# A directive that is itself continued over more than one line is
# reported at the line it starts on, since that is where the "#" is
# and where whoever reads the message goes looking.  The "#elif" here
# starts on line 4, after a macro written over three, and runs on to
# line 5: counting the lines as they are joined would put it at 5.

mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES   += c

BINARIES    += main
SOURCES     += main.c
EOF2

printf '%s\n' \
    '#define SUM(a, b) \' \
    '    ((a) + \' \
    '     (b))' \
    '#elif \' \
    '    1' \
    'int main(void) { return SUM(0, 0); }' > src/main.c

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    cat out
    exit 1
fi
cat out

grep -q "^src/main.c:4: " out
