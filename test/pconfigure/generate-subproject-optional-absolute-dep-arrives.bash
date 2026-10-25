#include "harness_start.bash"

# An optional input outside the tree is the shape the '?' was added
# for: a toolchain installed somewhere else, which the script asks
# after by its absolute path.  In a subproject that path was given the
# project's prefix before it was globbed, so the rule watched
# "sub//abs/path" -- a file that can never exist -- and the input
# arriving regenerated nothing.  Unlike a mandatory line, which at
# least stops the build, this one fails without a word.

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

cat >sub/src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     echo "?@OUTSIDE@" ;;
--generate) if test -f @OUTSIDE@
            then
                echo "#define ANSWER $(cat @OUTSIDE@)"
            else
                echo "#define ANSWER 0"
            fi ;;
esac
EOF
chmod +x sub/src/gen.h.proc

# Filled in here because the directory this runs in is only known now.
sed -i "s|@OUTSIDE@|$(pwd)/toolchain/answer.txt|g" sub/src/gen.h.proc
cat sub/src/gen.h.proc

cat >sub/src/app.c <<'EOF'
  #include "gen.h"
  #include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat sub/obj/Makefile.sub

make $MAKE_ARGS
test "$(./sub/bin/app)" = "0"

# The input arrives, newer than the output it should feed.
sleep 2
mkdir -p toolchain
echo 7 > toolchain/answer.txt
make $MAKE_ARGS
test "$(./sub/bin/app)" = "7"

exit 0
