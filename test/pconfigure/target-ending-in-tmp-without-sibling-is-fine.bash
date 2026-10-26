#include "harness_start.bash"

# What is refused is a target that IS another target's temporary, not
# one whose name merely ends in ".tmp".  A program called "x.tmp" with
# no "x" beside it, a header "api.h.tmp" next to an unrelated "gen.h",
# and a script "run" next to a program "runner.tmp" have nothing
# colliding, and have to keep building and installing.
mkdir -p src
echo 'int main(void) { return 7; }' > src/scratch.c
echo 'int main(void) { return 3; }' > src/runner.c
echo 'echo main' > src/run.bash
echo 'int api_template;' > src/template.h
echo 'int gen;' > src/gen.h

cat >Configfile <<'EOF2'
LANGUAGES += c
LANGUAGES += bash
LANGUAGES += h

BINARIES  += x.tmp
SOURCES   += scratch.c

BINARIES  += run
SOURCES   += run.bash

BINARIES  += runner.tmp
SOURCES   += runner.c

HEADERS   += api.h.tmp
SOURCES   += template.h

HEADERS   += gen.h
SOURCES   += gen.h
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
make $MAKE_ARGS DESTDIR=$tempdir/dest install

set +e
bin/x.tmp; x="$?"
bin/runner.tmp; runner="$?"
set -e
test "$x" == 7
test "$runner" == 3
test "$(bin/run)" == main
cmp src/template.h include/api.h.tmp
cmp src/gen.h include/gen.h

test -x dest/usr/local/bin/x.tmp
test -x dest/usr/local/bin/runner.tmp
test "$(dest/usr/local/bin/run)" == main
cmp src/template.h dest/usr/local/include/api.h.tmp
cmp src/gen.h dest/usr/local/include/gen.h

exit 0
