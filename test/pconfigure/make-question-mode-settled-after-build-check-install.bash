#include "harness_start.bash"

# "make -q" asks whether anything is out of date without building it,
# and exits 0 only when nothing is.  A generated Makefile that never
# settles -- a rule that always looks stale, a file rewritten on every
# run -- shows up here as a "make -q" that keeps saying 1 after the
# build it's asking about has just finished.  This checks the three
# goals people ask about, after each has been built, with a C binary,
# a shared library it links, a BASH script, a header and a test of
# each language.

mkdir -p src include test/hello

cat >Configfile <<'EOF'
LANGUAGES += c
LANGUAGES += bash

LIBRARIES += libx.so
SOURCES   += x.c

BINARIES  += hello
DEPLIBS   += x
SOURCES   += hello.c
TESTSRC   += runs.bash
TESTSRC   += runs.c

BINARIES  += script
SOURCES   += script.bash

HEADERS   += x.h
EOF

cat >include/x.h <<'EOF'
int x(void);
EOF

cat >src/x.c <<'EOF'
#include <x.h>
int x(void) { return 0; }
EOF

cat >src/hello.c <<'EOF'
#include <x.h>
int main(void) { return x(); }
EOF

cat >src/script.bash <<'EOF'
echo script
EOF

cat >test/hello/runs.bash <<'EOF'
"$PTEST_BINARY"
EOF

cat >test/hello/runs.c <<'EOF'
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS

make $MAKE_ARGS
make $MAKE_ARGS -q

make $MAKE_ARGS check
make $MAKE_ARGS -q check
make $MAKE_ARGS -q

make $MAKE_ARGS install DESTDIR="$tempdir/stage"
make $MAKE_ARGS -q install DESTDIR="$tempdir/stage"

# And before any of that has happened for a new DESTDIR, it says so.
if make $MAKE_ARGS -q install DESTDIR="$tempdir/elsewhere"
then
    exit 1
fi
test ! -e elsewhere

exit 0
