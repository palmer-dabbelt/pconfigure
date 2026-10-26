#include "harness_start.bash"

# An optional --deps line is recorded inside a $(foreach ...) filter,
# and make looks for a rule's colon before it expands anything, so the
# ':' inside the $(wildcard ...) is safe.  What the filter expands TO
# is not: make reads the expanded prerequisites for colons again, and a
# bare "src/a:b.txt" there ended in "multiple target patterns" -- for
# an input the script had marked as one the build can do without.  The
# filter now hands back each path it found spelled with "\:".
#
# The input starts out absent, arrives, and then changes, which takes
# the filter through both of its answers and through the fragment the
# build re-derives as well as the configure-time snapshot.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c
GENERATE  += gen.h
BINARIES  += app
SOURCES   += app.c
EOF

cat >src/gen.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--deps)     echo '?src/a:b.txt' ;;
--generate) if test -f 'src/a:b.txt'
            then echo "#define V $(cat 'src/a:b.txt')"
            else echo "#define V 0"
            fi ;;
esac
EOF
chmod +x src/gen.h.proc

cat >src/app.c <<'EOF'
#include "gen.h"
#include <stdio.h>
int main(void) { printf("%d\n", V); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "0"

sleep 2
echo 4 > 'src/a:b.txt'
make $MAKE_ARGS
test "$(./bin/app)" = "4"

sleep 2
echo 5 > 'src/a:b.txt'
make $MAKE_ARGS
test "$(./bin/app)" = "5"

exit 0
