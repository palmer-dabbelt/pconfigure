#include "harness_start.bash"

# GCC and Clang both take a '$' or a UTF-8 character as part of an
# identifier, so nothing$R and nothingéR are identifiers that end in R
# as much as nothingR is, and the quote after either opens an ordinary
# string.  Read as raw-string prefixes, their "(" opened a raw string
# that nothing ever closed, and every line after it was blanked as its
# body: the "#include" below went unseen and extra.c++ was never
# linked.

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
#define nothing$R
#define nothingéR
static const char *dollar = nothing$R"(";
static const char *utf8 = nothingéR"(";
#include "extra.h"
int main(void) { std::printf("%d%s%s\n", extra(), dollar, utf8); return 0; }
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "7(("
