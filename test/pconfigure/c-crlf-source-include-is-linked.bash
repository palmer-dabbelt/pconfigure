#include "harness_start.bash"

# A source with DOS line endings, which the compiler reads as though
# the carriage returns weren't there.  The scan has to as well: the
# "\r" on the end of a directive is trailing whitespace, not part of
# the header's name or of the "#endif".  The include comes after a
# conditional block that is never taken, so a scan that didn't see
# that block end would think the include is inside it and drop it.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += c

BINARIES  += app
SOURCES   += main.c
EOF

cat >src/extra.h <<'EOF'
int extra(void);
EOF

cat >src/extra.c <<'EOF'
#include "extra.h"
int extra(void) { return 7; }
EOF

printf '%s\r\n' \
    '#include <stdio.h>' \
    '#ifdef NO_EXTRA' \
    '#error "NO_EXTRA is never defined"' \
    '#endif' \
    '#include "extra.h"' \
    'int main(void) { printf("%d\n", extra()); return 0; }' \
    >src/main.c

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# The header is named without a carriage return on the end, and the
# source behind it is built.
test "$(grep '^obj/src/main\.c/[^ ]*\.o:' Makefile | tr ' ' '\n' | grep -cx src/extra.h)" = 1
grep -q '^obj/src/extra\.c/[^ ]*\.o:' Makefile
if grep -q "$(printf '\r')" Makefile
then
    exit 1
fi

make $MAKE_ARGS
test "$(./bin/app)" = "7"
