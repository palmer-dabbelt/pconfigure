#include "harness_start.bash"

# An absolute "#include" that names nothing is the compiler's to
# complain about, the way a relative one found nowhere is: the scan
# has no better sentence to say about it, and a header that some other
# machine has in a system directory is no reason to stop this one from
# configuring.  It is passed over without a word and without becoming
# a prerequisite, which make would then refuse to build anything for.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += app
SOURCES     += main.c
EOF

cat >src/main.c <<EOF
#include "$tempdir/nowhere/missing.h"
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS > pconfigure.out 2>&1
cat pconfigure.out
test ! -s pconfigure.out
cat Makefile
grep -q '^obj/src/main\.c/[^ ]*\.o: src/main\.c$' Makefile
if grep -q missing.h Makefile
then
    exit 1
fi
