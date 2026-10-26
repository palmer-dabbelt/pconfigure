#include "harness_start.bash"

# The same refusal for a source behind a header whose name has a brace
# list in it, under AUTORECONFIGURE, where the walk is pdeps' while the
# build runs.  Left bare in the compile recipe, 'v{a,b}.c' was handed
# to the compiler as 'src/va.c src/vb.c'; what has to happen instead is
# a build that stops and says why.
mkdir -p src
cat >Configfile <<'EOT2'
AUTORECONFIGURE = true
LANGUAGES   += c

BINARIES    += app
SOURCES     += main.c
EOT2
echo 'int extra(void);' > 'src/v{a,b}.h'
echo 'int extra(void) { return 7; }' > 'src/v{a,b}.c'
cat >src/main.c <<'EOT2'
#include "v{a,b}.h"
int main(void) { return extra(); }
EOT2

$PTEST_BINARY $PCONFIGURE_ARGS
set +e
timeout 120 make $MAKE_ARGS > out 2>&1
status="$?"
set -e
cat out
test "$status" != "0"
test "$status" != "124"
grep -qF "'src/main.c' reads 'src/v{a,b}.h', and the source behind it, 'src/v{a,b}.c', has a '{' in its name" out
