#include "harness_start.bash"
#pconfigure TESTDEPS += bin/pinclude

# "-DNAME(args)" and "-DNAME(args)=body" define the function-like
# macro NAME, as far as the compiler is concerned.  pinclude's command
# line cut the name only at an '=', so it kept "NAME(args)" as the
# name and an "#ifdef NAME" was off.

pinclude="$(dirname "$PTEST_BINARY")/pinclude"

cat >main.c <<'EOF2'
#ifdef LOG
#include "x.h"
#endif
EOF2

cat >x.h <<'EOF2'
int x(void);
EOF2

test "$("$pinclude" '-DLOG(x)' main.c)" = "x.h"
test "$("$pinclude" '-DLOG(x)=(x)' main.c)" = "x.h"
test "$("$pinclude" -D 'LOG(a,b)=a' main.c)" = "x.h"

# The name still has to be all of what comes before the '(', not
# something that merely starts the same way.
test "$("$pinclude" '-DLOGX(x)=(x)' main.c)" = ""
