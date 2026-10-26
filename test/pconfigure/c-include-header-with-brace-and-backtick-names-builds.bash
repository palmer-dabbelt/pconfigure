#include "harness_start.bash"

# A header found by the include scan, with no source behind it, is
# never compiled: its name only reaches make, as a prerequisite, and
# never a shell.  So the braces and backticks a target or source name
# is refused for are fine in one, and refusing them for sources behind
# headers mustn't reach the headers themselves.  Both with and without
# AUTORECONFIGURE, since the scan is pconfigure's in one and pdeps' in
# the other, and an edit to either header has to be noticed.
for auto in false true
do
    mkdir -p $auto/src
    cat >$auto/Configfile <<EOT2
AUTORECONFIGURE = $auto
LANGUAGES   += c

BINARIES    += app
SOURCES     += main.c
EOT2
    echo '#define A 3' > "$auto/src/a{b,c}.h"
    echo '#define B 4' > "$auto/src/w\`true\`.h"
    cat >$auto/src/main.c <<'EOT2'
#include <stdio.h>
#include "a{b,c}.h"
#include "w`true`.h"
int main(void) { printf("%d\n", A + B); return 0; }
EOT2

    (cd $auto && $PTEST_BINARY $PCONFIGURE_ARGS)
    (cd $auto && timeout 120 make $MAKE_ARGS)
    test "$($auto/bin/app)" = "7"

    sleep 1
    echo '#define A 5' > "$auto/src/a{b,c}.h"
    (cd $auto && timeout 120 make $MAKE_ARGS)
    test "$($auto/bin/app)" = "9"

    sleep 1
    echo '#define B 6' > "$auto/src/w\`true\`.h"
    (cd $auto && timeout 120 make $MAKE_ARGS)
    test "$($auto/bin/app)" = "11"
done
