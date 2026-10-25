#include "harness_start.bash"

# A checkout directory with a space in its name: the Makefile names
# everything relative to where it is, so building, the dependency
# walk that AUTORECONFIGURE moves into the build, and the reconfigure
# a Configfile edit sets off all have to work without ever spelling
# the directory out.  Running a test is the one step that does spell
# it out, which is a different question from the ones asked here, so
# this file leaves "make check" alone.
mkdir -p "my proj/src" "my proj/include"
cd "my proj"

echo '#define VALUE 0' > include/value.h
cat >src/main.c <<'EOF'
#include "value.h"
int main(void) { return VALUE; }
EOF
echo 'int helper(void) { return 0; }' > src/helper.c

cat >Configfile <<EOF
AUTORECONFIGURE = true

LANGUAGES += c

BINARIES  += main
SOURCES   += main.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
./bin/main

# A header edit is noticed through the dependency fragments.
sleep 1
echo '#define VALUE 3' > include/value.h
make $MAKE_ARGS
if ./bin/main
then
    exit 1
fi

# And a Configfile edit reconfigures on a plain make.
echo 'SOURCES   += helper.c' >> Configfile
make $MAKE_ARGS > out
cat out
grep -q "helper.c" out
