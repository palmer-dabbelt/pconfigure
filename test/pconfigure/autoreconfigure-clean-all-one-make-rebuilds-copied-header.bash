#include "harness_start.bash"

# "make clean all" in one invocation is the usual way to ask for a
# rebuild from scratch, and without AUTORECONFIGURE it works.  With it,
# each source's dependency fragment is an included makefile that names
# the headers it reads, so make looks at include/x.h -- a HEADERSRC
# copy -- while it is still deciding whether its makefiles are current,
# finds it present, and remembers that.  Then "clean" deletes the copy
# and "all" compiles hello.c without making it again: "x.h: No such
# file or directory".  Run serially, so there is no -j race to blame.

mkdir -p src

cat >Configfile <<'EOF2'
AUTORECONFIGURE = true
LANGUAGES       += c
LANGUAGES       += h

HEADERSRC       += x.h

BINARIES        += hello
SOURCES         += hello.c
EOF2

echo 'int x(void);' > src/x.h
cat >src/hello.c <<'EOF2'
#include <x.h>
int main(void) { return 0; }
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS -j1
test -x bin/hello

make $MAKE_ARGS -j1 clean all
test -x bin/hello
test -f include/x.h

exit 0
