#include "harness_start.bash"

# An include directory a subproject writes gets the subproject's
# directory put on its front, outside whatever quotes the subproject
# wrote it in: -I"sub/inc" in subproject "sub" goes to the compiler as
# -Isub/"sub/inc".  The object's name used to be hashed with "sub/"
# taken off wherever it started a word, and a quote starts one, so
# both of those came off and -I"sub/inc" hashed the same as -I"inc".
# Switching from one to the other then found the object already built
# against the first directory's header and kept it.  Only the "sub/"
# pconfigure put there is its to take back off.
mkdir -p sub/src sub/sub/inc sub/inc
cat >Configfile <<'EOT'
SUBPROJECTS += sub
EOT
cat >sub/Configfile <<'EOT'
LANGUAGES   += c
BINARIES    += app
COMPILEOPTS += -I"sub/inc"
SOURCES     += main.c
EOT
echo '#define WHERE "deep"' > sub/sub/inc/where.h
echo '#define WHERE "shallow"' > sub/inc/where.h
cat >sub/src/main.c <<'EOT'
#include <stdio.h>
#include <where.h>
int main(void) { puts(WHERE); return 0; }
EOT

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./sub/bin/app)" = "deep"

sed -i 's@-I"sub/inc"@-I"inc"@' sub/Configfile
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./sub/bin/app)" = "shallow"
