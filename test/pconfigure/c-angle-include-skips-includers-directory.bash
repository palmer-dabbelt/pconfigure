#include "harness_start.bash"

# "#include <time.h>" asks the compiler for the system's time.h, and
# the directory the source sits in is no part of where it looks: that
# is the whole difference between the angle brackets and the quotes.
# The scan looked beside the source first for both spellings, so a
# project with a timing module of its own in src/time.h had that
# header listed, and src/time.c built and linked into a program that
# never asked for it.  Here it doesn't compile, so the build says so.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += c

BINARIES  += app
SOURCES   += main.c
EOF

cat >src/time.h <<'EOF'
#error "src/time.h is the project's own header, not <time.h>"
EOF

cat >src/time.c <<'EOF'
#error "src/time.c is not part of app"
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
#include <time.h>
int main(void) { printf("%d\n", (int)sizeof(time_t) > 0); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

if grep -q "src/time\.[ch]" Makefile
then
    exit 1
fi

make $MAKE_ARGS
test "$(./bin/app)" = "1"
