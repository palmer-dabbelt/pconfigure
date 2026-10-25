#include "harness_start.bash"

# Every installed file is a make target of its own, so a second
# "make install" with nothing changed copies nothing, and one after a
# single installed file was deleted puts back that file and leaves
# the others -- by their modification times -- alone.
mkdir -p src include
echo 'int f(void) { return 0; }' > src/f.c
echo 'int main(void) { return 0; }' > src/main.c
echo 'echo hi' > src/script.bash
echo 'int f(void);' > include/f.h

cat >Configfile <<'EOF2'
LANGUAGES += c
LANGUAGES += bash

LIBRARIES += libf.so
SOURCES   += f.c

BINARIES  += main
SOURCES   += main.c

BINARIES  += script
SOURCES   += script.bash

HEADERS   += f.h
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS DESTDIR=$tempdir/dest install
find dest -type f | sort > first
test "$(wc -l < first)" -eq 4

sleep 1
touch settled.stamp
make $MAKE_ARGS DESTDIR=$tempdir/dest install
test -z "$(find dest -type f -newer settled.stamp)"

rm dest/usr/local/bin/script
make $MAKE_ARGS DESTDIR=$tempdir/dest install
find dest -type f -newer settled.stamp > rewritten
cat rewritten
echo dest/usr/local/bin/script > expected
diff -u expected rewritten

find dest -type f | sort > second
diff -u first second
