#include "harness_start.bash"

# "%:" is the digraph for '#', standard since C95 and in every C++, and
# the preprocessor reads "%:include" as "#include".  The scan only
# looked for a '#', so it passed the line over: extra.h was not a
# prerequisite and extra.c was never linked, though the compiler had
# read the header and the link needed what it declares.

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

cat >src/main.c <<'EOF'
%:include "extra.h"
int main(void) { return extra() == 7 ? 0 : 1; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
./bin/app
