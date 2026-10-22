#include "harness_start.bash"

# "-l foo" is as legal a way to ask the linker for a library as
# "-lfoo" is, and a LINKOPTS line is a command line, so either spelling
# has to reach the linker the way it was written.  The duplicate-library
# filter on the link line works on words, and the bare "-l" is a word
# that looks like a library flag: dropping the second one as a repeat
# leaves "-l one two", which asks for libone and then for a file called
# "two" in the current directory.  The two libraries here are both
# needed, so a link that loses either one fails outright.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

LIBRARIES += libone.so
SOURCES   += one.c

LIBRARIES += libtwo.so
SOURCES   += two.c

BINARIES  += app
LINKOPTS  += -L lib -l one -l two
SOURCES   += main.c
EOF

cat >src/one.c <<'EOF'
int one(void) { return 1; }
EOF

cat >src/two.c <<'EOF'
int two(void) { return 2; }
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
int one(void);
int two(void);
int main(void) { printf("%d\n", one() + two()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# Both of the flags made it onto the link line, each with its word.
grep -q -- "-l one -l two" Makefile

make $MAKE_ARGS
test "$(./bin/app)" = "3"
