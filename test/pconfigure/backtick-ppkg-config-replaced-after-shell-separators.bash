#include "harness_start.bash"

# "ppkg-config" is replaced as a word rather than only where it starts
# a backticked command: a word starts after a pipe, a ';', a '&&', a
# '$(' or a subshell's '(' just as it does after a space.  Each of
# those below has to reach the stand-in named by --ppkg-config, which
# logs every call, rather than whatever $PATH would find; a rule that
# was tightened to keep "ppkg-config" out of paths and longer words
# should not have lost any of these on the way.
mkdir -p src

cat >my-ppkg <<'EOF2'
#!/bin/bash
echo "$@" >>"$MY_PPKG_LOG"
echo "-DFROM_MY_PPKG=1"
EOF2
chmod +x my-ppkg
export MY_PPKG_LOG="$(pwd)/my-ppkg.log"

cat >Configfile <<'EOF2'
LANGUAGES   += c

BINARIES    += test
COMPILEOPTS += `true|ppkg-config pipe`
COMPILEOPTS += `true;ppkg-config semicolon`
COMPILEOPTS += `true&&ppkg-config and`
COMPILEOPTS += `echo $(ppkg-config dollar-paren)`
COMPILEOPTS += `(ppkg-config subshell)`
COMPILEOPTS += `	ppkg-config tab`
SOURCES     += test.c
EOF2

cat >src/test.c <<'EOF2'
#include <stdio.h>
int main(void) { printf("%d\n", FROM_MY_PPKG); return 0; }
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS --ppkg-config "$(pwd)/my-ppkg"
cat my-ppkg.log

for word in pipe semicolon and dollar-paren subshell tab
do
    grep -qx "$word" my-ppkg.log
done
test "$(wc -l <my-ppkg.log)" = "6"

make $MAKE_ARGS
test "$(./bin/test)" = "1"
