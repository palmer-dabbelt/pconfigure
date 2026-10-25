#include "harness_start.bash"

# A subproject's -I"$$SUBINC" is a directory the shell finds out about
# when the compiler runs, and the double quotes are what leave $SUBINC
# for it to expand.  Rerooting the directory puts the subproject in
# front of it, and that has to leave the writer's quoting alone: spelt
# again in single quotes, the compiler was handed a directory called
# a/$SUBINC and found no value.h in it.  "-isystem$$SUBSYS" is the same
# with the quote opened before the flag, which comes back out as the
# flag and then the quote.
#
# The top of the tree has an inc/ and a sys/ of its own so that
# looking there rather than in the subproject is a wrong answer and
# not just a missing header, and all of it has to hold from inside the
# subproject too, where the subproject's directory is spelt with
# nothing on the front.

mkdir -p a/src a/inc a/sys inc sys

cat >Configfile <<'EOF'
SUBPROJECTS += a
EOF

cat >inc/value.h <<'EOF'
#define VALUE 100
EOF

cat >sys/other.h <<'EOF'
#define OTHER 100
EOF

cat >a/Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -I"$$SUBINC"
COMPILEOPTS += "-isystem$$SUBSYS"
SOURCES     += main.c
EOF

cat >a/inc/value.h <<'EOF'
#define VALUE 1
EOF

cat >a/sys/other.h <<'EOF'
#define OTHER 10
EOF

cat >a/src/main.c <<'EOF'
#include <stdio.h>
#include <value.h>
#include <other.h>
int main(void) { printf("%d\n", VALUE + OTHER); return 0; }
EOF

export SUBINC=inc
export SUBSYS=sys

$PTEST_BINARY $PCONFIGURE_ARGS
cat a/obj/Makefile.a
make $MAKE_ARGS
test "$(./a/bin/app)" = "11"

(cd a && $PTEST_BINARY $PCONFIGURE_ARGS)
(cd a && timeout 60 make $MAKE_ARGS)
test "$(cd a && ./bin/app)" = "11"
