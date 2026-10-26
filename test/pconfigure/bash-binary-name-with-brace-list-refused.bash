#include "harness_start.bash"

# The BASH backend writes its own recipes, separately from the C one,
# and pasted the program's name into "pbashc -i src/s.bash -o bin/s{1,2}"
# bare.  bash expanded the braces, so pbashc was handed "-o bin/s1
# bin/s2" and refused a second input it was never meant to see.  The
# refusal is asked of the line before any backend sees it, so it holds
# here too.
mkdir -p src
echo 'echo hi' > src/s.bash
cat >Configfile <<'EOT2'
LANGUAGES += bash

BINARIES  += s{1,2}
SOURCES   += s.bash
EOT2

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    echo "a bash BINARIES with a brace list in its name was accepted" >&2
    exit 1
fi
cat out
grep -q "Configfile:3" out
grep -qF "BINARIES has a '{' in it: 's{1,2}'" out
test ! -e Makefile
