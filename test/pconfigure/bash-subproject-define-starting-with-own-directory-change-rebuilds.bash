#include "harness_start.bash"

# The BASH counterpart of
# subproject-define-starting-with-own-directory-change-recompiles: a
# script isn't named by a hash at all, since its record holds the whole
# pbashc recipe as written, so "-DWHERE=sub/marine" and
# "-DWHERE=marine" are two different records and the change rebuilds
# the script.  Pinned so that the two languages keep agreeing that a
# '-D' value is the subproject's own text, whatever it starts with.
mkdir -p sub/src
cat >Configfile <<'EOT'
SUBPROJECTS += sub
EOT
cat >sub/Configfile <<'EOT'
LANGUAGES   += bash
BINARIES    += app
COMPILEOPTS += -DWHERE=sub/marine
SOURCES     += app.bash
EOT
cat >sub/src/app.bash <<'EOT'
#!/bin/bash
echo WHERE
EOT

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./sub/bin/app)" = "sub/marine"

sed -i 's@=sub/marine@=marine@' sub/Configfile
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./sub/bin/app)" = "marine"
