#include "harness_start.bash"

# Text inside a backticked command that has "ppkg-config" somewhere in
# the middle of a longer word is not the program being run: here it
# is the value of a macro, in single quotes, handed to echo.  The
# compile has to see exactly the value written, rather than one with
# the path of pconfigure's tools pasted into it.

export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src

cat >Configfile <<'EOC'
LANGUAGES   += c
COMPILEOPTS += `echo '-DNAME=\"myppkg-config\"'`
BINARIES    += app
SOURCES     += main.c
EOC

cat >src/main.c <<'EOC'
#include <stdio.h>
int main(void) { printf("%s\n", NAME); return 0; }
EOC

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "myppkg-config"
