#include "harness_start.bash"

# A raw string's delimiter can be any characters but a space, a
# parenthesis, a backslash or a control character, and a quote is
# none of those: R""(/* )"" is the string "/* ", delimited by a quote.
# Turned away as a delimiter, the quote after the R was read as an
# empty ordinary string, which left the slash-star as code, and the
# comment it opened hid the "#include" below, so extra.c++ was never
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
static const char *open_comment = R""(/* )"";
#include "extra.h"
int main(void) { std::printf("%d%s\n", extra(), open_comment); return 0; }
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "7/* "
