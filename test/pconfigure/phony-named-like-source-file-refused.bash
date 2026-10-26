#include "harness_start.bash"

# "PHONY += src/hello.c" names a file the build compiles.  It landed in
# the Makefile as ".PHONY: src/hello.c", which makes the source of a
# real object always out of date: every "make" recompiled and relinked
# hello, and "make -q" never said the tree was current.  Two rules
# that write one file are already refused; a PHONY over a file the
# build reads is the same collision from the other side, and is
# refused at its line, naming the line that reads the file.  The
# SOURCES comes after the PHONY here, so the question can't be
# answered at the PHONY's own line.

mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES += c

PHONY     += ./src/hello.c

BINARIES  += hello
SOURCES   += hello.c
EOF2

echo 'int main(void) { return 0; }' > src/hello.c

if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
then
    cat configure.out
    echo "PHONY += ./src/hello.c was accepted" >&2
    exit 1
fi
cat configure.out

grep -q "^./Configfile:3" configure.out
grep -qF "error: PHONY can't be called './src/hello.c'" configure.out
grep -qF "Configfile:6 'SOURCES += hello.c' reads it" configure.out
grep -qF "give the PHONY a name of its own" configure.out
test ! -e Makefile
