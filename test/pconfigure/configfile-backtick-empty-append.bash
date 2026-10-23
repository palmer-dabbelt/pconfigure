#include "harness_start.bash"

# Adding nothing to a list is a legal thing for a command in backticks
# to ask for, and the usual one: "pkg-config --cflags zlib" and
# "pkg-config --libs-only-L zlib" both print nothing for a library that
# lives where the compiler already looks.  So "COMPILEOPTS += `...`"
# whose command printed nothing is a line that adds nothing, not the
# bare "COMPILEOPTS +=" somebody forgot to finish, which is refused.
#
# The same goes for a command that printed nothing in amongst other
# words: the words around it are still added, with no stray gap where
# it was.
mkdir -p src
cat >src/main.c <<'EOF2'
#include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF2

cat >Configfile <<'EOF2'
LANGUAGES   += c

COMPILEOPTS += `true`
LINKOPTS    += `true`
COMPILEOPTS += `echo "   "`
COMPILEOPTS += -DANSWER=42 `true` -Wall
LINKOPTS    += `true` -L.
BINARIES    += main
SOURCES     += main.c
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1 || {
    cat out
    echo "an append whose backtick printed nothing was refused" >&2
    exit 1
}
cat out

# The words either side of an empty backtick are one gap apart, as if
# the backtick had never been written.
grep -q -- '-DANSWER=42 -Wall' Makefile

make $MAKE_ARGS
test "$(./bin/main)" = 42

# A bare "+=" that somebody typed is still the mistake it always was:
# it's only what a backtick printed that gets to be nothing.
mkdir -p typed/src
cp src/main.c typed/src/main.c
cat >typed/Configfile <<'EOF2'
LANGUAGES   += c

COMPILEOPTS +=
BINARIES    += main
SOURCES     += main.c
EOF2

if (cd typed && $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1)
then
    cat typed/out
    echo "a bare COMPILEOPTS += was accepted" >&2
    exit 1
fi
cat typed/out
