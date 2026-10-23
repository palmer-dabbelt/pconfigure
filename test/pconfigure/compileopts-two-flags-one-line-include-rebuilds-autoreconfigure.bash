#include "harness_start.bash"

# The include-path half of compileopts-two-flags-one-line-define-seen.
# "-Wall -Iextra" on one COMPILEOPTS line compiles fine -- the shell
# splits it -- but a header search that read the line as one flag
# would never find extra/answer.h, and so never make it a prerequisite
# of the object.  Editing the header would then rebuild nothing and
# the program would go on answering with the old value.
#
# AUTORECONFIGURE = true, which is what decides who reads the options:
# pconfigure does under false and pdeps does under true, and the two
# have to agree with each other as well as with the compiler.

mkdir -p src extra

cat >Configfile <<EOC
AUTORECONFIGURE = true

LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -Wall -Iextra
SOURCES     += main.c
EOC

cat >extra/answer.h <<'EOC'
#define ANSWER 1
EOC

cat >src/main.c <<'EOC'
#include <stdio.h>
#include "answer.h"
int main(void) { printf("%d\n", ANSWER); return 0; }
EOC

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "1"

# Far enough apart that a filesystem with one-second timestamps still
# sees the header as newer than the object.
sleep 2
cat >extra/answer.h <<'EOC'
#define ANSWER 2
EOC

make $MAKE_ARGS
test "$(./bin/app)" = "2"
