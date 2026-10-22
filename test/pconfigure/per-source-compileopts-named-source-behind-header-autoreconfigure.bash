#include "harness_start.bash"

# The same leak as per-source-compileopts-stay-off-shared-header-source,
# with the source behind the header also named outright.  util.c is
# compiled the target's way because the Configfile names it, and then
# main.c -- the one source with a -D of its own -- reaches util.c
# again through util.h and asks for it built with main.c's options.
#
# AUTORECONFIGURE = true, and here that second request is an include of
# a fragment nobody writes a rule for: pdeps leaves named sources to
# the Makefile's rule, and that rule is for the other set of options.
# Make stops on "No rule to make target".

mkdir -p src

cat >Configfile <<EOF
AUTORECONFIGURE = true

LANGUAGES   += c

BINARIES    += app
SOURCES     += util.c
SOURCES     += main.c
COMPILEOPTS += -DMAIN_SCALE=3
EOF

cat >src/util.h <<'EOF'
int util(void);
EOF

cat >src/util.c <<'EOF'
#include "util.h"
int util(void) { return 7; }
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
#include "util.h"
int main(void) { printf("%d\n", util() * MAIN_SCALE); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "21"

test "$(ls obj/src/util.c/*-static.o | wc -l)" -eq 1
