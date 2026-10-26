#include "harness_start.bash"

# A ".." inside a --deps path is the same problem as a "./": a script
# that names its sibling output as "src/../obj/./proc/a.h" names the
# file a.h's rule builds, but make compares names rather than files,
# so "sub/src/../obj/./proc/a.h" is somewhere no rule builds.
#
# The fragment the build re-derives is checked too, because it is a
# second spelling of the same answer, made by sed rather than by
# pconfigure: it has to name a.h the way a.h's rule does.

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
--deps)     echo "src/../obj/./proc/a.h" ;;
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

find sub/obj -name 'b.h*.d' | xargs cat
find sub/obj -name 'b.h*.d' | xargs grep -q 'obj/proc/a\.h'
if find sub/obj -name 'b.h*.d' | xargs grep -q '\.\./\|/\./'
then
    exit 1
fi

exit 0
