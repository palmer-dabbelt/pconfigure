#include "harness_start.bash"

# A source saved by an editor that writes a UTF-8 byte order mark
# starts with three bytes before its first '#'.  gcc and clang skip a
# leading byte order mark, so the first line is still an "#include".
# The scan only lets whitespace come before a directive's '#', so it
# read the line as code, never saw extra.h, and left extra.c out of
# the link.
#
# Written with printf, since the bytes have to be exactly these.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += app
SOURCES     += main.c
EOF

cat >src/extra.h <<'EOF'
int extra(void);
EOF

cat >src/extra.c <<'EOF'
#include "extra.h"
int extra(void) { return 7; }
EOF

printf '\357\273\277%s\n' '#include "extra.h"' > src/main.c
cat >>src/main.c <<'EOF'
int main(void) { return extra() == 7 ? 0 : 1; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
./bin/app
