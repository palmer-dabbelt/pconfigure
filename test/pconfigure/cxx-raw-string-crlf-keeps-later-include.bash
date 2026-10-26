#include "harness_start.bash"

# A source with CRLF line endings has a carriage return at the end of
# every line the scan reads, inside a raw string's body as much as
# anywhere.  The string still has to end at its own ")" and quote, and
# the "#include" after it still has to be seen, or extra.c++ is never
# linked; the "#include" inside it still has to be left alone, or
# fake.c++, which doesn't compile, is built.

mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES   += c++

BINARIES    += app
SOURCES     += main.c++
EOF2

cat >src/fake.h <<'EOF2'
int fake(void);
EOF2

cat >src/fake.c++ <<'EOF2'
#error fake.c++ is only named inside a string
EOF2

cat >src/extra.h <<'EOF2'
int extra(void);
EOF2

cat >src/extra.c++ <<'EOF2'
#include "extra.h"
int extra(void) { return 7; }
EOF2

printf '%s\r\n' \
    '#include <cstdio>' \
    'static const char *tmpl = R"x(' \
    '#include "fake.h"' \
    ')x";' \
    '#include "extra.h"' \
    'int main(void) { std::printf("%d\n", extra()); return tmpl[0] == 0; }' \
    >src/main.c++

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

if grep -q "fake" Makefile
then
    exit 1
fi

make $MAKE_ARGS
test "$(./bin/app)" = "7"
