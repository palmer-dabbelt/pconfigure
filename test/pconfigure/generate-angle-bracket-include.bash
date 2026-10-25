#include "harness_start.bash"

# A generated header is found through the include path rather than
# next to the source that reads it, so '#include <gen.h>' finds it as
# surely as '#include "gen.h"' does -- and the dependency on it is
# recorded either way, so an edit to the script's input rebuilds the
# consumer.  A scanner that only followed the quoted form would build
# the first time and go stale after.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

GENERATE  += gen.h

BINARIES  += app
SOURCES   += app.c
EOF

echo 4 > src/answer.txt

cat >src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     echo "src/answer.txt" ;;
--generate) echo "#define ANSWER $(cat src/answer.txt)" ;;
esac
EOF
chmod +x src/gen.h.proc

cat >src/app.c <<'EOF'
  #include <gen.h>
  #include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

make $MAKE_ARGS
test "$(./bin/app)" = "4"

sleep 2
echo 6 > src/answer.txt
make $MAKE_ARGS
test "$(./bin/app)" = "6"

exit 0
