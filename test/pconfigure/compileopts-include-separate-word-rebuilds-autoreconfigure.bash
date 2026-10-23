#include "harness_start.bash"

# "-I dir" is "-Idir" spelled with a space, which every compiler
# accepts and which the link side already accepts for "-L dir".  The
# header search has to take the next word as the directory, rather
# than reading " extra" as one, or the header it finds there is never
# a prerequisite of the object and editing it rebuilds nothing.
#
# AUTORECONFIGURE = true, which is what decides who reads the options:
# pconfigure does under false and pdeps does under true, and the two
# have to agree with each other as well as with the compiler.

mkdir -p src extra

cat >Configfile <<EOC
AUTORECONFIGURE = true

LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -I extra
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
