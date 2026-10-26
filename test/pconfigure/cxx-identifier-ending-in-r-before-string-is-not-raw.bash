#include "harness_start.bash"

# Only R, u8R, uR, UR or LR as a whole token make the quote after them
# open a raw string.  An identifier that merely ends in R is the
# identifier, and the quote after it opens an ordinary string -- here
# an empty macro pasted against "(".  Read as a raw string, that "("
# opened one that nothing ever closed, and every line after it was
# blanked as its body: the "#include" below went unseen and extra.c++
# was never linked.

mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES   += c++

BINARIES    += app
SOURCES     += main.c++
EOF2

cat >src/extra.h <<'EOF2'
int extra(void);
EOF2

cat >src/extra.c++ <<'EOF2'
#include "extra.h"
int extra(void) { return 7; }
EOF2

cat >src/main.c++ <<'EOF2'
#include <cstdio>
#define nothingR
static const char *open_paren = nothingR"(";
#include "extra.h"
int main(void) { std::printf("%d%s\n", extra(), open_paren); return 0; }
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "7("
