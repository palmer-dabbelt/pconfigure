#include "harness_start.bash"

# A GENERATE writes into obj/proc, and a binary's objects and link
# scratch land under obj/ too, so a binary called "proc" is the name
# most likely to collide with the generated-output directory.  It
# doesn't: the link scratch goes under obj/bin/proc, the generated
# header stays where the include path says it is, and "make clean"
# followed by "make" rebuilds both.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

GENERATE  += gen.h

BINARIES  += proc
SOURCES   += app.c
EOF

cat >src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--generate) echo "#define ANSWER 3" ;;
esac
EOF
chmod +x src/gen.h.proc

cat >src/app.c <<'EOF'
  #include "gen.h"
  #include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

make $MAKE_ARGS
test "$(./bin/proc)" = "3"
test -f obj/proc/gen.h
grep -q "define ANSWER 3" obj/proc/gen.h

make $MAKE_ARGS clean
test ! -e obj/proc/gen.h
test ! -e bin/proc
make $MAKE_ARGS
test "$(./bin/proc)" = "3"
grep -q "define ANSWER 3" obj/proc/gen.h

exit 0
