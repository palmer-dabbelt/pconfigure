#include "harness_start.bash"

# A name that make has to be told is a name -- a ':' in it, see
# config-deps-path-with-colon-watched -- is spelled inside a function
# call, where a ',' is what separates the arguments.  One in the same
# name has to come through whole rather than splitting the call and
# leaving the rule a prerequisite short, or a build that stops on the
# half that is left.

mkdir -p src

cat >Configfile <<'EOC'
AUTORECONFIGURE  = true
CONFIG_DEPS     += notes,1:2.txt
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
EOC

echo 'int main(void) { return 0; }' > src/main.c
echo 1 > 'notes,1:2.txt'

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS > first.log 2>&1 || { cat first.log; exit 1; }
cat first.log

make $MAKE_ARGS > settled.log 2>&1 || { cat settled.log; exit 1; }
cat settled.log
if grep -q PCONFIGURE settled.log
then
    exit 1
fi

sleep 1
echo 2 > 'notes,1:2.txt'
make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
grep -q PCONFIGURE second.log
