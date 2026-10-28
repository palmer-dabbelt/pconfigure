#include "harness_start.bash"

# "--ppkg-config PATH" replaces the word ppkg-config inside every
# backtick with PATH, so the person running the build decides which
# copy answers.  A stand-in records each call, which shows that it is
# the one that ran (for every backtick that names it, and for nothing
# else), and what it prints is what reaches the compile line.
mkdir -p src

cat >my-ppkg <<'EOF'
#!/bin/bash
echo "$@" >>"$MY_PPKG_LOG"
echo "-DFROM_MY_PPKG=1"
EOF
chmod +x my-ppkg
export MY_PPKG_LOG="$(pwd)/my-ppkg.log"

cat >Configfile <<EOF
LANGUAGES   += c

BINARIES    += test
COMPILEOPTS += \`ppkg-config --optional thing --cflags\`
LINKOPTS    += \`echo -lm\`
SOURCES     += test.c
EOF

cat >src/test.c <<EOF
#include <stdio.h>
int main(void) { printf("%d\n", FROM_MY_PPKG); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS --ppkg-config "$(pwd)/my-ppkg"
cat my-ppkg.log

test "$(wc -l <my-ppkg.log | tr -d ' ')" = "1"
grep -q "^--optional thing --cflags$" my-ppkg.log
grep -q -- "-DFROM_MY_PPKG=1" Makefile

make $MAKE_ARGS
test "$(./bin/test)" = "1"

exit 0
