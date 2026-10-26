#include "harness_start.bash"

# The top-of-tree half of the subproject tests beside this one.  At the
# top there is no prefix to paste on, but a ".." or "./" inside a
# --deps path is still a different name to make from the target it
# means, so "src/../obj/./proc/a.h" left b.h waiting on a file nothing
# builds.  The paths are tidied wherever the project sits.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c
GENERATE  += a.h
GENERATE  += b.h
BINARIES  += app
SOURCES   += app.c
EOF

cat >src/a.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--generate) echo "#define A 4" ;;
esac
EOF

cat >src/b.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--deps)     echo "src/../obj/./proc/a.h" ;;
--generate) sed 's/define A /define ANSWER /' obj/proc/a.h ;;
esac
EOF
chmod +x src/a.h.proc src/b.h.proc

cat >src/app.c <<'EOF'
#include "b.h"
#include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(bin/app)" = "4"

make $MAKE_ARGS clean
make $MAKE_ARGS -j2
test "$(bin/app)" = "4"

exit 0
