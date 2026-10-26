#include "harness_start.bash"

# The same file reached two ways in one project.  src/.c is found and
# compiled behind src/.h when main.c includes it; written out as
# "SOURCES += .c" as well, it is the very same source named outright,
# which the manual says is fine.  It was refused with "Unable to find
# language" instead, so adding a line that named what was already
# being built broke a configure that had worked a moment before.  It
# has to build either way, and only once: the source named outright
# and the one found behind the header are one object, not two that
# collide at link time.
mkdir -p src
echo 'int v(void) { return 4; }' > src/.c
echo 'int v(void);' > src/.h
cat >src/main.c <<'EOT'
#include ".h"
int main(void) { return v(); }
EOT

# Found behind the header, it builds.
cat >Configfile <<'EOT'
LANGUAGES   += c
BINARIES    += app
SOURCES     += main.c
EOT
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
set +e
./bin/app
got=$?
set -e
test "$got" = 4

# Named outright as well, it has to build the same.
cat >>Configfile <<'EOT'
SOURCES     += .c
EOT
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
set +e
./bin/app
got=$?
set -e
test "$got" = 4
