#include "harness_start.bash"

# A --deps path lands on the generated file's rule line, where make
# reads a ':' as the separator of a static pattern rule.  So a script
# that names "src/a:b.txt" -- an ordinary file name everywhere but in a
# Makefile -- used to get "multiple target patterns" from make, about a
# Makefile the user didn't write, from a pconfigure that had exited 0
# having written it.  "\:" is make's spelling of a ':' that belongs to
# the file name, so the path is written that way and the build works.
#
# Both halves of the rule carry the path: the configure-time snapshot
# and the ".d" fragment the build re-derives from the script's live
# answer.  The first make writes the fragment and every make after it
# reads it, so the edit below is seen through both.  The subproject
# spelling roots the path behind a make variable after escaping it,
# and the second project checks that the two orders agree.

mkdir -p src sub/src

cat >Configfile <<'EOF'
LANGUAGES   += c
GENERATE    += gen.h
BINARIES    += app
SOURCES     += app.c
SUBPROJECTS += sub
EOF

cat >sub/Configfile <<'EOF'
LANGUAGES   += c
GENERATE    += gen.h
BINARIES    += subapp
SOURCES     += app.c
EOF

for d in . sub
do
    echo 4 > "$d/src/a:b.txt"

    cat >"$d/src/gen.h.proc" <<'EOF'
#!/bin/sh
case "$1" in
--deps)     echo 'src/a:b.txt' ;;
--generate) echo "#define V $(cat 'src/a:b.txt')" ;;
esac
EOF
    chmod +x "$d/src/gen.h.proc"

    cat >"$d/src/app.c" <<'EOF'
#include "gen.h"
#include <stdio.h>
int main(void) { printf("%d\n", V); return 0; }
EOF
done

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "4"
test "$(./sub/bin/subapp)" = "4"

cat obj/proc/gen.h.d
grep -qF 'src/a\:b.txt' obj/proc/gen.h.d

sleep 2
echo 5 > 'src/a:b.txt'
make $MAKE_ARGS
test "$(./bin/app)" = "5"
test "$(./sub/bin/subapp)" = "4"

sleep 2
echo 6 > 'sub/src/a:b.txt'
make $MAKE_ARGS
test "$(./bin/app)" = "5"
test "$(./sub/bin/subapp)" = "6"

exit 0
