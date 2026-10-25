#include "harness_start.bash"

# A C header with a source beside it pulls that source into the link
# even when the Configfile never names it.  Under AUTORECONFIGURE the
# fragment for such a source is written by a rule pdeps writes into
# the fragment of the source that included the header, and that rule
# runs pdeps by its absolute path.  It is pdeps, not pconfigure,
# writing that recipe, so with the tools under a directory with a
# space in it the rule has to quote the path itself or the build runs
# "/.../my" and stops with exit 127.

here_bin="$(dirname "$PTEST_BINARY")"
mkdir -p "my tools/bin" "my tools/lib"
cp "$here_bin"/* "my tools/bin/"
cp "$here_bin"/../lib/*.so "my tools/lib/"
pconfigure="$(pwd)/my tools/bin/pconfigure"
test -x "$pconfigure"

mkdir -p src

echo 'int value(void);' > src/value.h
echo 'int value(void) { return 3; }' > src/value.c
cat >src/main.c <<'EOC'
#include "value.h"
int main(void) { return value(); }
EOC

cat >Configfile <<'EOC'
AUTORECONFIGURE  = true
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
EOC

"$pconfigure" $PCONFIGURE_ARGS
make $MAKE_ARGS > build.log 2>&1 || { cat build.log; exit 1; }
cat build.log

# The sibling's fragment came from the rule under test, not from one
# pconfigure wrote, so check that rule is what ran.
grep -q 'DEPS.*value\.c' build.log

set +e
./bin/main
status=$?
set -e
test "$status" = 3
