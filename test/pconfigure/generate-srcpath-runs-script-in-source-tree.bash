#include "harness_start.bash"

# The manual says a GENERATE script is run "from the top of the project
# that owns the script", and that what --deps prints is named relative
# to that project.  With --srcpath the project is the source tree, not
# the build directory pconfigure was run from.  Today the script is run
# from the build directory, so it can't find src/answer.txt at all, and
# the "src/answer.txt" it printed is written into the Makefile
# unrooted, which make can't find either: "No rule to make target
# 'src/answer.txt'".  The same Configfile builds in place.

mkdir -p tree/src build

cat >tree/Configfile <<EOF
LANGUAGES += c
GENERATE  += gen.h
BINARIES  += app
SOURCES   += app.c
EOF

echo 4 > tree/src/answer.txt

cat >tree/src/gen.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--deps)     echo "src/answer.txt" ;;
--generate) echo "#define ANSWER $(cat src/answer.txt)" ;;
esac
EOF
chmod +x tree/src/gen.h.proc

cat >tree/src/app.c <<'EOF'
#include "gen.h"
#include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

cd build
$PTEST_BINARY $PCONFIGURE_ARGS --srcpath ../tree
make $MAKE_ARGS
test "$(./bin/app)" = "4"

sleep 2
echo 5 > ../tree/src/answer.txt
make $MAKE_ARGS
test "$(./bin/app)" = "5"

exit 0
