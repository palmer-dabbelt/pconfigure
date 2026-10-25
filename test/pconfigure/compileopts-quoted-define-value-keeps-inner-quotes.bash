#include "harness_start.bash"

# -DGREETING='"hi"' is how a string macro is written on a command
# line: the shell takes off the single quotes and leaves the double
# ones, so the compiler is handed GREETING as the string literal
# "hi".  Taking the quotes off for the header scan mustn't take off
# more than the shell does, and it mustn't stop the scan from seeing
# the plain -D"WANT_EXTRA" beside it on the same line, which is what
# brings extra.c into the link.

mkdir -p src

cat >Configfile <<'EOC'
LANGUAGES   += c
COMPILEOPTS += -DGREETING='"hi"' -D"WANT_EXTRA"
BINARIES    += app
SOURCES     += main.c
EOC

cat >src/extra.h <<'EOC'
int extra(void);
EOC

cat >src/extra.c <<'EOC'
#include "extra.h"
int extra(void) { return 7; }
EOC

cat >src/main.c <<'EOC'
#include <stdio.h>
#ifdef WANT_EXTRA
#include "extra.h"
#endif
int main(void)
{
#ifdef WANT_EXTRA
    printf("%s %d\n", GREETING, extra());
#else
    printf("%s none\n", GREETING);
#endif
    return 0;
}
EOC

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "hi 7"
