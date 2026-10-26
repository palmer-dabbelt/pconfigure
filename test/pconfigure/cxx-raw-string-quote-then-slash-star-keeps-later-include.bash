#include "harness_start.bash"

# A C++ raw string takes every character between its delimiters as it
# is, quotes included, so R"(" /* )" is a string holding a quote, a
# space and a slash-star.  The comment blanking walks string literals
# with ordinary-string rules: the quote inside the raw string closed
# it, and the slash-star after it opened a block comment that ran on
# over the "#include" on the next line.  The scan never saw extra.h,
# extra.c++ was never built, and the link failed.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES   += c++

BINARIES    += app
SOURCES     += main.c++
EOF

cat >src/extra.h <<'EOF'
int extra(void);
EOF

cat >src/extra.c++ <<'EOF'
#include "extra.h"
int extra(void) { return 7; }
EOF

cat >src/main.c++ <<'EOF'
#include <cstdio>
static const char *glob = R"(" /* )";
#include "extra.h"
int main(void) { std::printf("%d %s\n", extra(), glob); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = '7 " /* '
