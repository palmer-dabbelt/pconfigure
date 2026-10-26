#include "harness_start.bash"

# A HEADERS copy is made while pconfigure configures, through the same
# shell the Makefile's recipes use, and bash expanded "h{a,b}.h" into
# two names.  phc was then handed a source and an output that weren't
# the ones written, failed, and pconfigure blamed the include
# directory: "check that include is a directory pconfigure can write",
# which it is.  The line is refused for its '{' instead, before any
# copy is tried.
mkdir -p src
echo 'int x;' > 'src/h{a,b}.h'
cat >Configfile <<'EOT2'
LANGUAGES   += h
HEADERS     += h{a,b}.h
SOURCES     += h{a,b}.h
EOT2

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    echo "a HEADERS with a brace list in its name was accepted" >&2
    exit 1
fi
cat out
grep -q "Configfile:2" out
grep -qF "HEADERS has a '{' in it: 'h{a,b}.h'" out
if grep -q "a directory pconfigure can write" out
then
    echo "a brace in a header's name was blamed on the include directory" >&2
    exit 1
fi
test ! -e include
