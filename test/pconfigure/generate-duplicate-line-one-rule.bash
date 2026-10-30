#include "harness_start.bash"

# The same GENERATE written twice -- two Configfile fragments that
# both want the header, say -- is one output with one rule.  Two rules
# for one target is something make warns about and then resolves by
# picking one, so the Makefile has to hold exactly one, and the build
# has to run the script once.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

GENERATE  += gen.h
GENERATE  += gen.h

BINARIES  += app
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

test "$(grep -c '^obj/proc/gen.h:' Makefile)" = "1"
test "$(grep -c '^obj/proc/gen.h.d:' Makefile)" = "1"

make $MAKE_ARGS > build.out 2>&1
cat build.out
if grep -q "warning: overriding" build.out
then
    exit 1
fi
test "$(./bin/app)" = "3"

sleep 2
sed -i.bak 's/ANSWER 3/ANSWER 4/' src/gen.h.proc
make $MAKE_ARGS > again.out 2>&1
cat again.out
test "$(grep -c '^GEN' again.out)" = "1"
test "$(./bin/app)" = "4"

exit 0
