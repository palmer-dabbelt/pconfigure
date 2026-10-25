#include "harness_start.bash"

# Under AUTORECONFIGURE the C dependency walk moves into the build,
# where pdeps does it, and a Configfile edit reruns pconfigure from a
# recipe.  Both are named by the absolute path pconfigure was run
# from, so a pconfigure under a directory with a space in it has to
# write them as one word each -- for the first build, the header edit
# after it, and the reconfigure a Configfile edit sets off.

here_bin="$(dirname "$PTEST_BINARY")"
mkdir -p "my tools/bin" "my tools/lib"
cp "$here_bin"/* "my tools/bin/"
cp "$here_bin"/../lib/*.so "my tools/lib/"
pconfigure="$(pwd)/my tools/bin/pconfigure"
test -x "$pconfigure"

mkdir -p src

echo '#define VALUE 0' > src/value.h
cat >src/main.c <<'EOC'
#include "value.h"
int main(void) { return VALUE; }
EOC

cat >Configfile <<'EOC'
AUTORECONFIGURE  = true
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
EOC

"$pconfigure" $PCONFIGURE_ARGS
make $MAKE_ARGS
./bin/main

sleep 1
echo '#define VALUE 3' > src/value.h
make $MAKE_ARGS
if ./bin/main
then
    exit 1
fi

sleep 1
echo 'COMPILEOPTS += -DUNUSED' >> Configfile
make $MAKE_ARGS > reconfigure.log 2>&1 || { cat reconfigure.log; exit 1; }
cat reconfigure.log
grep -q PCONFIGURE reconfigure.log
