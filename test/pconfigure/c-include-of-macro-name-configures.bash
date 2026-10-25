#include "harness_start.bash"

# "#include NAME", with NAME a macro that expands to the header, is
# standard C and is how a project picks a configuration header without
# an "#ifdef" ladder.  The scan can't expand it, since it tracks which
# names are defined and not what they are defined as, and what it can't
# name it can't list.  What it did instead was abort with "Unknown
# include format", naming no file, so the project could not be
# configured at all.
#
# The include after it is an ordinary one, and is checked for: passing
# over the line the scan can't read mustn't stop it reading the rest of
# the file.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += c

BINARIES  += app
SOURCES   += main.c
EOF

cat >src/config-default.h <<'EOF'
#define VALUE 7
EOF

cat >src/extra.h <<'EOF'
int extra(void);
EOF

cat >src/extra.c <<'EOF'
#include "extra.h"
int extra(void) { return 0; }
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
#define CONFIG_HEADER "config-default.h"
#include CONFIG_HEADER
#include "extra.h"
int main(void) { printf("%d\n", VALUE + extra()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "7"
