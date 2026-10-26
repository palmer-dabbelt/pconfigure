#include "harness_start.bash"

# An executable Configfile is run from the directory it lives in,
# because a project's own generator only knows about its own tree.  A
# backtick in a plain Configfile is the same kind of thing, and a
# project that reads its version out of a file next to its Configfile
# configures on its own -- but pulled into a parent with SUBPROJECTS,
# its backtick ran in the parent's directory and "cat version" failed.
mkdir -p lib/src
echo 42 > lib/version
echo 'int main(void) { return V - 42; }' > lib/src/v.c
cat >lib/Configfile <<'EOF2'
LANGUAGES   += c
BINARIES    += v
COMPILEOPTS += -DV=`cat version`
SOURCES     += v.c
EOF2

# On its own it works.
( cd lib && $PTEST_BINARY $PCONFIGURE_ARGS && make $MAKE_ARGS && ./bin/v )
rm -rf lib/Makefile lib/obj lib/bin

echo 'SUBPROJECTS += lib' > Configfile
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
./lib/bin/v

exit 0
