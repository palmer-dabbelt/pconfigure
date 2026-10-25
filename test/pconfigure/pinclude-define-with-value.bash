#include "harness_start.bash"
#pconfigure TESTDEPS += bin/pinclude

# "-DNAME=value" defines NAME, which is what pconfigure's own reading
# of COMPILEOPTS says and what the compiler says.  pinclude's command
# line kept the whole of "NAME=value" as the name, so an "#ifdef NAME"
# was off and the include under it was left off the list.  The value
# is dropped whether the flag is glued to it or a word of its own.

pinclude="$(dirname "$PTEST_BINARY")/pinclude"

cat >main.c <<'EOF2'
#ifdef WANT_X
#include "x.h"
#endif
EOF2

cat >x.h <<'EOF2'
int x(void);
EOF2

test "$("$pinclude" -DWANT_X main.c)" = "x.h"
test "$("$pinclude" -DWANT_X=1 main.c)" = "x.h"
test "$("$pinclude" -D WANT_X=1 main.c)" = "x.h"

# A name that is only a prefix of what was defined is still not
# defined: the value is cut off at the '=', not the name shortened.
test "$("$pinclude" -DWANT_XY=1 main.c)" = ""
