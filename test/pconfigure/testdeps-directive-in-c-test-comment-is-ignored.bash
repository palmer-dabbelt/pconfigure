#include "harness_start.bash"

# A script is read for its includes and directives line by line, the
# way a shell reads it, and the C preprocessor's comments and
# backslash-newlines mean nothing in one.  A C test is read for its
# "#pconfigure" lines with the same strict spelling, but it is still
# C: a line inside one of its block comments, or one a "//" comment
# swallows with a trailing backslash, is commented out, and a
# directive there is one nobody meant to take effect.  Reading it
# anyway makes the check wait on a target that doesn't exist.
mkdir -p src test/main

cat >Configfile <<'EOF'
LANGUAGES += c

BINARIES  += main
SOURCES   += main.c
TESTSRC   += t.c
EOF

echo 'int main(void) { return 0; }' > src/main.c

# Written with printf rather than a heredoc, since a '#' in the first
# column of this file is read by the pconfigure that builds it.
{
    echo '/* Needs a tool nobody has written yet:'
    printf '%s\n' '#pconfigure TESTDEPS += bin/no-such-block-tool'
    echo ' */'
    printf '%s\n' '// waits on the other one too \'
    printf '%s\n' '#pconfigure TESTDEPS += bin/no-such-line-tool'
    echo 'int main(void) { return 0; }'
} > test/main/t.c

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

if grep -q "no-such-.*-tool" Makefile
then
    exit 1
fi

make $MAKE_ARGS check
test "$(tar -xOf check/main/t.c ptest__return)" = 0
