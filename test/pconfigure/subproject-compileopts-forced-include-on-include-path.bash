#include "harness_start.bash"

# A subproject's "-include config.h" can also mean the config.h on its
# include path, when there is none beside its Configfile: the compiler
# tries its own directory first and then goes on down the path.  Put
# the subproject's directory on the front of that name and the path
# search would be looking for "a/config.h" under "a/inc", which isn't
# there -- so a name that doesn't name a file in the subproject is
# left to the search, the way the subproject's author saw it work.

mkdir -p a/src a/inc

cat >Configfile <<'EOF'
SUBPROJECTS += a
EOF

cat >a/Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -Iinc -include config.h
SOURCES     += main.c
EOF

cat >a/inc/config.h <<'EOF'
#define VALUE 1
EOF

cat >a/src/main.c <<'EOF'
#include <stdio.h>
int main(void) { printf("%d\n", VALUE); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
cat a/obj/Makefile.a
make $MAKE_ARGS
test "$(./a/bin/app)" = "1"

find . -type f -exec touch -d '2000-01-01' {} +

cat >a/inc/config.h <<'EOF'
#define VALUE 2
EOF

make $MAKE_ARGS
test "$(./a/bin/app)" = "2"
