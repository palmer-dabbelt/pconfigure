#include "harness_start.bash"

# A subproject's --deps paths are rooted by putting the subproject's
# directory on the front, and that used to be all that happened to
# them: "./obj/proc/a.h" became "sub/./obj/proc/a.h".  make drops a
# leading "./" but nothing inside a path, so to make that is a
# different file from "sub/obj/proc/a.h", the target of a.h's rule.
# After make clean neither generated header exists, b.h's rule asks
# for a file that no rule builds, and a parallel make that reaches b.h
# first stops with "No rule to make target" instead of generating a.h.
# At the top of a tree the same script works, because there the "./"
# is leading; a script shouldn't mean something different depending on
# who pulled its project in.

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

cat >sub/src/a.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--generate) echo "#define A 4" ;;
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

make $MAKE_ARGS clean
make $MAKE_ARGS -j2
test "$(sub/bin/app)" = "4"

exit 0
