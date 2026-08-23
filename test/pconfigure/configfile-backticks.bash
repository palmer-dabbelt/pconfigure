#include "harness_start.bash"

mkdir -p src

# A backtick runs a command and puts what it printed in the line, and
# the line goes on afterwards: the closing backtick ends the command
# and nothing else.
cat >Configfile <<EOF
LANGUAGES   += c

BINARIES    += test
COMPILEOPTS += -DGREETING=\"\`echo hell\`o\"
COMPILEOPTS += -DTAIL=\"pre\`echo mid\`post\"
SOURCES     += \`echo test.c\`

# This is a comment, and a comment is not a command: \`touch PWNED\`
#\`touch PWNED_NOSPACE\`
   #	\`touch PWNED_INDENTED\`
EOF

cat >src/test.c <<EOF
  #include <stdio.h>

int main(void)
{
    printf("%s %s\n", GREETING, TAIL);
    return 0;
}
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# A comment never runs, however it was indented and whatever it has in
# it.  Substitution used to happen before anything looked for the '#',
# so commenting a line out ran half of it anyway.
test ! -e PWNED
test ! -e PWNED_NOSPACE
test ! -e PWNED_INDENTED

# Everything after the closing backtick is still part of the line.
# This used to be dropped, which silently truncated anything that had
# one of these in the middle of a line rather than at the end of it.
grep -q 'DGREETING=\\"hello\\"' Makefile
grep -q 'DTAIL=\\"premidpost\\"' Makefile

make $MAKE_ARGS
test "$(./bin/test)" = "hello premidpost"

# A backtick with no closing backtick has swallowed the rest of the
# line and there's no way to know where it was meant to stop, so
# pconfigure says so rather than running a prefix of it.
mkdir -p unterminated/src
cat >unterminated/Configfile <<EOF
LANGUAGES += c

BINARIES  += test
SOURCES   += \`echo test.c
EOF
cp src/test.c unterminated/src/test.c

if (cd unterminated && $PTEST_BINARY $PCONFIGURE_ARGS) > unterminated.out 2>&1
then
    exit 1
fi
cat unterminated.out
grep -q "unterminated" unterminated.out

exit 0
