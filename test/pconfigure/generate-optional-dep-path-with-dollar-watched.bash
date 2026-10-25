#include "harness_start.bash"

# An optional --deps line reaches the Makefile inside a $(wildcard),
# where a '$' is still an expansion: "?src/cost$1.txt" was looked for
# as "src/cost.txt", which is never there, so the input was dropped as
# absent and editing it regenerated nothing -- the silent version of
# the "No rule to make target" a mandatory line gets.  A '#' inside the
# function call is an ordinary character to make, and has to stay one:
# escaping it there as it is escaped on a rule line would hand the
# glob a backslash it never asked for.  Both are printed, so that the
# escaping is seen to be the right one for where the path lands.

mkdir -p src

cat >Configfile <<'EOC'
LANGUAGES   += c
GENERATE    += gen.h
BINARIES    += app
SOURCES     += main.c
EOC

cat >src/gen.h.proc <<'EOC'
#!/bin/bash
case "$1" in
--deps)
    echo '?src/cost$1.txt'
    echo '?src/notes#1.txt'
    ;;
--generate)
    echo "#define VALUE $(cat 'src/cost$1.txt')$(cat 'src/notes#1.txt')"
    ;;
esac
EOC
chmod +x src/gen.h.proc

echo 1 > 'src/cost$1.txt'
echo 0 > 'src/notes#1.txt'

cat >src/main.c <<'EOC'
#include <stdio.h>
#include "gen.h"
int main(void) { printf("%d\n", VALUE); return 0; }
EOC

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "10"

sleep 1
echo 2 > 'src/cost$1.txt'
make $MAKE_ARGS
test "$(./bin/app)" = "20"

sleep 1
echo 5 > 'src/notes#1.txt'
make $MAKE_ARGS
test "$(./bin/app)" = "25"
