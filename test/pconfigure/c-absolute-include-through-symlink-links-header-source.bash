#include "harness_start.bash"

# A project reached through a symlink, with its header included by the
# path the shell knows it by.  That is $PWD, which keeps the link,
# while getcwd() resolves it, and the header was recognized as the
# project's own only when its path began with getcwd()'s answer.  It
# didn't, so the header stayed an outside file, the source behind it
# was never built, and the link failed on extra().  A checkout under a
# symlinked home directory is like this, and on macOS so is everything
# mktemp hands out, since /var is a link to /private/var.

mkdir -p real/src
ln -s real link
cd link

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += app
SOURCES     += main.c
EOF

cat >src/extra.h <<'EOF'
int extra(void);
EOF

cat >src/extra.c <<'EOF'
int extra(void) { return 7; }
EOF

cat >src/main.c <<EOF
#include <stdio.h>
#include "$PWD/src/extra.h"
int main(void) { printf("%d\n", extra()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "7"
