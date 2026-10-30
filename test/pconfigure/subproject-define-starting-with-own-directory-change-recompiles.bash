#include "harness_start.bash"

# An object in a subproject is named by a hash of its compile line as
# the subproject would spell it, so that the top of a run and the
# subproject configured on its own agree on the name.  Only what
# pconfigure itself rooted at the subproject gets respelled, though,
# not every word that happens to start with the subproject's
# directory: a '-D' whose value starts with "sub/" is what the
# subproject wrote, and taking "sub/" off it hashed -DWHERE="sub/marine"
# the same as -DWHERE="marine".  Changing one into the other named the
# very object that was already built, make found it up to date, and
# the program went on printing the old string.
mkdir -p sub/src
cat >Configfile <<'EOT'
SUBPROJECTS += sub
EOT
cat >sub/Configfile <<'EOT'
LANGUAGES   += c
BINARIES    += app
COMPILEOPTS += -DWHERE='"sub/marine"'
SOURCES     += main.c
EOT
cat >sub/src/main.c <<'EOT'
#include <stdio.h>
int main(void) { puts(WHERE); return 0; }
EOT

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./sub/bin/app)" = "sub/marine"

sed -i.bak 's@"sub/marine"@"marine"@' sub/Configfile
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./sub/bin/app)" = "marine"
