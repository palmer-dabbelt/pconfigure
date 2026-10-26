#include "harness_start.bash"

# A GENERATE's script is a source somebody wrote as much as a SOURCES
# is, and the generated file is built from it.  A PHONY with the
# script's name would have every make regenerate the output and
# rebuild everything that includes it, so it is refused like a PHONY
# named after any other file the build reads.

mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES += c

GENERATE  += gen.h

BINARIES  += hello
SOURCES   += hello.c

PHONY     += src/gen.h.proc
EOF2

cat >src/gen.h.proc <<'EOF2'
#!/bin/bash
echo "#define X 0"
EOF2
chmod +x src/gen.h.proc

cat >src/hello.c <<'EOF2'
#include "gen.h"
int main(void) { return X; }
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
then
    cat configure.out
    echo "PHONY += src/gen.h.proc was accepted" >&2
    exit 1
fi
cat configure.out

grep -q "^./Configfile:8" configure.out
grep -qF "error: PHONY can't be called 'src/gen.h.proc'" configure.out
grep -qF "Configfile:3 'GENERATE += gen.h' reads it" configure.out
test ! -e Makefile
