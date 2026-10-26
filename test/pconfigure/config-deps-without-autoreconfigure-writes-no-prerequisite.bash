#include "harness_start.bash"

# A CONFIG_DEPS line in a project that neither asked for AUTORECONFIGURE
# nor keeps a committed Makefile (no BOOTSTRAP).  The prerequisite the
# line adds is there for a recipe to act on, and such a project has
# none: nothing it names could ever lead to a reconfigure.  What a
# recipe-less "Makefile: <deps>" line would still do is have make
# remake whatever the names have a rule for before it looks at any
# goal, so "make clean" would rebuild a binary a CONFIG_DEPS named.
# So the generated Makefile names nothing at all here, and the build
# carries on undisturbed when a watched directory gains a file.

mkdir -p src tests

cat >Configfile <<'EOC'
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
CONFIG_DEPS     += tests
CONFIG_DEPS     += absent
EOC

echo 'int main(void) { return 0; }' > src/main.c

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# No prerequisite line for the Makefile itself, in either spelling.
if grep -q '^Makefile:' Makefile
then
    exit 1
fi

make $MAKE_ARGS > first.log 2>&1 || { cat first.log; exit 1; }
cat first.log
test -x bin/main

# The directory moving on leaves a build that still works and does not
# configure: running pconfigure again is something a person asks for.
cp Makefile Makefile.before
sleep 1
touch tests/new
timeout 60 make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
if grep -q "^PCONFIGURE$" second.log
then
    exit 1
fi
cmp Makefile Makefile.before
