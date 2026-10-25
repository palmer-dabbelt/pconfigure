#include "harness_start.bash"

# What is refused is a GENERATE output that IS another GENERATE's
# scratch file, not one that merely ends the way scratch files do.  A
# project generating a makefile fragment called "rules.d", or a
# template called "page.tmp", next to an unrelated "gen.h" has nothing
# colliding, and has to keep building.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

GENERATE  += gen.h
GENERATE  += rules.d
GENERATE  += page.tmp

BINARIES  += app
SOURCES   += app.c
EOF

cat >src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--generate) echo "#define ANSWER 3" ;;
esac
EOF

cat >src/rules.d.proc <<'EOF'
#!/bin/bash
case "$1" in
--generate) echo "rules" ;;
esac
EOF

cat >src/page.tmp.proc <<'EOF'
#!/bin/bash
case "$1" in
--generate) echo "page" ;;
esac
EOF
chmod +x src/*.proc

cat >src/app.c <<'EOF'
  #include "gen.h"
  #include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "3"
grep -q "^rules$" obj/proc/rules.d
grep -q "^page$" obj/proc/page.tmp

exit 0
