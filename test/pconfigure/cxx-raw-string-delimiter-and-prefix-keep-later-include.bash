#include "harness_start.bash"

# A raw string only ends at a ")" followed by the delimiter it opened
# with and a quote, so a ")" and a quote inside one, with no delimiter
# between them, are text like the rest of it.  Taken for the end of
# the string they let the slash-star after them open a comment that
# hid the real "#include" below; and the string has a "u8" in front
# of its R, which has to be read as a raw string as much as a bare R
# is, or the template's own "#include" is followed and fake.c -- a
# file that doesn't compile -- is built into the program.

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

cat >src/main.c++ <<'EOF2'
#include <cstdio>
static const char *tmpl = (const char *)u8R"tmpl(
")" /* not a comment
#include "fake.h"
)tmpl";
#include "extra.h"
int main(void) { std::printf("%d\n", extra()); return tmpl[0] == '\n' ? 0 : 1; }
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

if grep -q "fake" Makefile
then
    exit 1
fi

make $MAKE_ARGS
test "$(./bin/app)" = "7"
