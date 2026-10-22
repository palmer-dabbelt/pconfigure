#include "harness_start.bash"

# The other half of subproject-compileopts-isystem-relative.bash: a
# directory named with "-isystem" is one the compiler searches, so a
# header found there is one the object was built against, and editing
# it has to rebuild the object.  The search for headers used to know
# only about "-I", so the header was found by the compiler and was a
# prerequisite of nothing -- the program went on printing the old
# value after the edit.

mkdir -p a/src a/inc

cat >Configfile <<EOF
SUBPROJECTS += a
EOF

cat >a/Configfile <<EOF
LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -isystem inc
SOURCES     += main.c
EOF

cat >a/inc/answer.h <<'EOF'
#define ANSWER 1
EOF

cat >a/src/main.c <<'EOF'
#include <stdio.h>
#include <answer.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat a/obj/Makefile.a
make $MAKE_ARGS
test "$(./a/bin/app)" = "1"

sleep 2
cat >a/inc/answer.h <<'EOF'
#define ANSWER 2
EOF

make $MAKE_ARGS
test "$(./a/bin/app)" = "2"
