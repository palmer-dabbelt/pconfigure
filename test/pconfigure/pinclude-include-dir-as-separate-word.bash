#include "harness_start.bash"
#pconfigure TESTDEPS += bin/pinclude

# pinclude takes its include path the way a compiler does, and a
# compiler takes "-I dir" as two words just as well as "-Idir" as one.
# pinclude read the bare "-I" as an include directory with an empty
# name and "inc" as the file to scan, which the source then replaced:
# the header was looked for at "/x.h", and nothing was listed.

pinclude="$(dirname "$PTEST_BINARY")/pinclude"

mkdir -p inc

cat >main.c <<'EOF2'
#include "x.h"
EOF2

cat >inc/x.h <<'EOF2'
int x(void);
EOF2

test "$("$pinclude" -Iinc main.c)" = "inc/x.h"
test "$("$pinclude" -I inc main.c)" = "inc/x.h"

# The file can come first, too: "-I" takes the one word after it and
# nothing else.
test "$("$pinclude" main.c -I inc)" = "inc/x.h"
