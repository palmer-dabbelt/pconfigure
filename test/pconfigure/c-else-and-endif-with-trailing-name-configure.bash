#include "harness_start.bash"

# "#else VERBOSE" and "#endif VERBOSE" -- the name of the conditional
# written after the directive with no comment around it -- is a habit
# older than "//", and the compiler still takes both, warning about the
# extra tokens.  The scan aborted on them with "There shouldn't be
# anything after an endif", naming neither the file nor the line, so a
# project the compiler builds could not be configured at all.
#
# Accepting the line isn't enough: it has to do what the compiler does
# with it.  VERBOSE is off, so the "#else" branch is the one taken, and
# the header in it is what brings extra.c into the link.  The header in
# the other branch has a source behind it that doesn't compile, so
# reading the labelled "#else" as anything but an "#else" shows up as a
# failed build rather than a quiet extra dependency.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += c

BINARIES  += app
SOURCES   += main.c
EOF

cat >src/verbose.h <<'EOF'
int verbose(void);
EOF

cat >src/verbose.c <<'EOF'
#error "verbose.c is only meant to be built with VERBOSE"
EOF

cat >src/extra.h <<'EOF'
int extra(void);
EOF

cat >src/extra.c <<'EOF'
#include "extra.h"
int extra(void) { return 7; }
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
#ifdef VERBOSE
#include "verbose.h"
#else VERBOSE
#include "extra.h"
#endif VERBOSE
int main(void) { printf("%d\n", extra()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

if grep -q "src/verbose\.[ch]" Makefile
then
    exit 1
fi

make $MAKE_ARGS
test "$(./bin/app)" = "7"
