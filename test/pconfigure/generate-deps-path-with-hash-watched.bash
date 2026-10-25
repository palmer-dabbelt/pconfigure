#include "harness_start.bash"

# What a GENERATE script prints for --deps is a list of paths, and
# they go into the Makefile as the generated file's prerequisites --
# here, in a rule line pconfigure writes and in the .d fragment the
# build keeps current.  A path with a character make reads specially
# has to be written so make reads it back as that path: a '#' starts a
# comment on a rule line, so the rest of the line -- the rest of this
# path and every input printed after it -- is thrown away, and make
# stops on "No rule to make target 'src/notes'", naming a file that
# was never printed.  Nothing in the Configfile can be pointed at for
# it either, since the path came from the script.

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
    echo 'src/notes#1.txt'
    echo 'src/value.txt'
    ;;
--generate)
    echo "#define VALUE $(cat src/value.txt)$(cat 'src/notes#1.txt')"
    ;;
esac
EOC
chmod +x src/gen.h.proc

echo 1 > src/value.txt
echo 0 > 'src/notes#1.txt'

cat >src/main.c <<'EOC'
#include <stdio.h>
#include "gen.h"
int main(void) { printf("%d\n", VALUE); return 0; }
EOC

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "10"

# Both inputs are watched: the one after the odd path as much as the
# odd path itself.
sleep 1
echo 2 > src/value.txt
make $MAKE_ARGS
test "$(./bin/app)" = "20"

sleep 1
echo 5 > 'src/notes#1.txt'
make $MAKE_ARGS
test "$(./bin/app)" = "25"
