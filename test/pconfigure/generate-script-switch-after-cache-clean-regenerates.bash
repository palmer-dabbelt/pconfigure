#include "harness_start.bash"

# What tells a configure that a GENERATE's output was written by some
# other script is the record of the recipe that wrote it, kept in the
# object directory beside the output.  "make cache-clean" throws away
# whatever in there the Makefile doesn't name, and a record that went
# with it is a record the next configure reads as "never kept" -- which
# it has to trust, since that is also what a tree configured before
# records were kept looks like.  So a cache-clean followed by a switch
# of script would have kept the old script's answer.

mkdir -p src other

cat >src/gen.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--generate) echo "#define V 1" ;;
esac
EOF
cat >other/gen.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--generate) echo "#define V 2" ;;
esac
EOF
chmod +x src/gen.h.proc other/gen.h.proc

cat >src/app.c <<'EOF'
#include "gen.h"
#include <stdio.h>
int main(void) { printf("%d\n", V); return 0; }
EOF

cat >Configfile <<EOF
LANGUAGES += c
GENERATE  += gen.h
BINARIES  += app
SOURCES   += app.c
EOF

sleep 2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "1"

make $MAKE_ARGS cache-clean
test -f obj/proc/gen.h

cat >Configfile <<EOF
LANGUAGES += c
SRCDIR     = other
GENERATE  += gen.h
SRCDIR     = src
BINARIES  += app
SOURCES   += app.c
EOF
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "2"

exit 0
