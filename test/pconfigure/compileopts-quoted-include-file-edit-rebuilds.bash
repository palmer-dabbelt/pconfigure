#include "harness_start.bash"

# The manual makes a file named by "-include" a header of every source,
# so that editing it rebuilds what was compiled with it.  Quoting the
# name, as "-include 'src/config.h'", changes nothing the compiler
# sees -- and so must change nothing about what gets rebuilt.

mkdir -p src

cat >Configfile <<'EOC'
LANGUAGES   += c
COMPILEOPTS += -include 'src/config.h'
BINARIES    += app
SOURCES     += main.c
EOC

echo '#define VALUE 1' > src/config.h

cat >src/main.c <<'EOC'
#include <stdio.h>
int main(void) { printf("%d\n", VALUE); return 0; }
EOC

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "1"

sleep 1
echo '#define VALUE 2' > src/config.h
make $MAKE_ARGS
test "$(./bin/app)" = "2"
