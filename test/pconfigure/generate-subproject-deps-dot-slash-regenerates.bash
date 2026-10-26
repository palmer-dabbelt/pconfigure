#include "harness_start.bash"

# The incremental face of "sub/./obj/proc/a.h": b.h's rule names a
# file make thinks is not a.h, so b.h does not wait for a.h, and when
# a.h is regenerated make has already stat'ed the other spelling and
# leaves b.h alone.  The program goes on printing the old answer.  It
# shows under -j2, where make is free to take b.h before a.h; a serial
# make happens to reach a.h first.

mkdir -p sub/src

cat >Configfile <<EOF
SUBPROJECTS += sub
EOF

cat >sub/Configfile <<EOF
LANGUAGES += c
GENERATE  += a.h
GENERATE  += b.h
BINARIES  += app
SOURCES   += app.c
EOF

echo 4 > sub/src/answer.txt

cat >sub/src/a.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--deps)     echo "./src/answer.txt" ;;
--generate) echo "#define A $(cat src/answer.txt)" ;;
esac
EOF

cat >sub/src/b.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--deps)     echo "./obj/proc/a.h" ;;
--generate) sed 's/define A /define ANSWER /' obj/proc/a.h ;;
esac
EOF
chmod +x sub/src/a.h.proc sub/src/b.h.proc

cat >sub/src/app.c <<'EOF'
#include "b.h"
#include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(sub/bin/app)" = "4"

sleep 2
echo 9 > sub/src/answer.txt
make $MAKE_ARGS -j2
cat sub/obj/proc/a.h sub/obj/proc/b.h
test "$(sub/bin/app)" = "9"

exit 0
