#include "harness_start.bash"

# An absolute path printed by "--deps" -- a system file the script
# reads, or a toolchain installed outside the tree -- names one file
# wherever it is read from.  In a subproject it was given the
# project's prefix anyway, so the rule depended on "sub//abs/path",
# which does not exist, and the build stopped with "No rule to make
# target".  At the top of a tree the same script works.

mkdir -p sub/src

cat >Configfile <<EOF
SUBPROJECTS += sub
EOF

cat >sub/Configfile <<EOF
LANGUAGES += c

GENERATE  += gen.h

BINARIES  += app
SOURCES   += app.c
EOF

echo 4 > sub/src/answer.txt

cat >sub/src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     echo "@OUTSIDE@" ;;
--generate) echo "#define ANSWER $(cat @OUTSIDE@)" ;;
esac
EOF
chmod +x sub/src/gen.h.proc

cat >sub/src/app.c <<'EOF'
  #include "gen.h"
  #include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

# The script is written with its absolute path filled in afterwards,
# since the directory this runs in is only known once it is running.
echo 4 > outside.txt
sed -i "s|@OUTSIDE@|$(pwd)/outside.txt|g" sub/src/gen.h.proc
cat sub/src/gen.h.proc

$PTEST_BINARY $PCONFIGURE_ARGS
cat sub/obj/Makefile.sub

make $MAKE_ARGS
test "$(./sub/bin/app)" = "4"

sleep 2
echo 5 > outside.txt
make $MAKE_ARGS
test "$(./sub/bin/app)" = "5"

exit 0
