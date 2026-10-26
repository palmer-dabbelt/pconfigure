#include "harness_start.bash"

# A raw string that spans several lines is how C++ code that writes C
# keeps a template readable, and its lines are text, not directives:
# the compiler never opens runtime.h for this program.  The scan reads
# a line at a time with no idea a raw string is open, so it took the
# "#include" inside the string for a real one and built and linked
# runtime.c -- here a file that doesn't even compile -- into the
# generator.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES   += c
LANGUAGES   += c++

BINARIES    += gen
SOURCES     += gen.c++
EOF

cat >src/runtime.h <<'EOF'
int runtime(void);
EOF

cat >src/runtime.c <<'EOF'
#error runtime.c belongs to the generated program, not the generator
EOF

cat >src/gen.c++ <<'EOF'
#include <cstdio>
static const char *tmpl = R"(
#include "runtime.h"
int main(void) { return runtime(); }
)";
int main(void) { std::fputs(tmpl, stdout); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

if grep -q "runtime" Makefile
then
    exit 1
fi

make $MAKE_ARGS
./bin/gen | grep -q 'include "runtime.h"'
