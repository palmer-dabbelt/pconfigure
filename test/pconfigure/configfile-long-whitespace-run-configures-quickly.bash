#include "harness_start.bash"

# Every Configfile line is tidied -- runs of white space squeezed to
# one space, the ends trimmed -- before it is read, and more than once
# on the way through.  That tidy is a single pass over the line, so a
# long line costs about as much as reading it.  Lines are allowed to
# be long (a generator printing every define it found is what makes
# one), and a tidy that rescans the whole line for every character it
# looks at turns two megabytes into minutes of configuring.  Linear,
# it is well under a second, so the timeout here leaves a generous
# margin for a loaded machine while still being far short of what the
# quadratic version takes.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

{
    echo 'LANGUAGES   += c'
    echo 'BINARIES    += main'
    printf 'COMPILEOPTS += -DA'
    head -c 2000000 /dev/zero | tr '\0' ' '
    printf -- '-DB\n'
    echo 'SOURCES     += main.c'
} > Configfile
test $(wc -c < Configfile | tr -d ' ') -gt 2000000

timeout 20 $PTEST_BINARY $PCONFIGURE_ARGS

# The run of spaces still has to come out as the one space it means,
# or this would pass just as well by not tidying at all.
grep -q -- "-DA -DB" Makefile
