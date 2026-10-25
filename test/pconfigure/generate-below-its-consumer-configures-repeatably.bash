#include "harness_start.bash"

# Running pconfigure twice over an unchanged tree has to write the same
# Makefile twice.  A GENERATE written below the source that includes
# its output broke that: the first run scanned app.c before the header
# had been generated and so recorded no dependency on it, and the
# second run found the header left on disk by the first and recorded
# one.  Whether an edited generator input rebuilt the binary then
# depended on how many times the tree had been configured.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

BINARIES  += app
SOURCES   += app.c

GENERATE  += gen.h
EOF

cat >src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--generate) echo "#define ANSWER 1" ;;
esac
EOF
chmod +x src/gen.h.proc

cat >src/app.c <<'EOF'
  #include "gen.h"
  #include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cp Makefile first.mk

$PTEST_BINARY $PCONFIGURE_ARGS
cp Makefile second.mk

diff -u first.mk second.mk

# Identical could also mean both runs missed the header, so the
# object's own rule has to name it from the first run on.  The
# generated rule for the header names it too, which is why this looks
# for it on the object's line rather than anywhere at all.
grep -q '^obj/src/app\.c/[^:]*\.o:.* obj/proc/gen\.h' first.mk
