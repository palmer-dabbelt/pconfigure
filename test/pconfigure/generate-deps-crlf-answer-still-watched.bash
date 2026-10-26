#include "harness_start.bash"

# A script that echoes paths it read out of a file with DOS line
# endings prints each one with a '\r' on the end.  Two lines, so that
# the two places the answer lands are each tested for what they would
# actually get wrong.
#
# The configure-time snapshot puts every path on the one rule, so it
# reads "obj/proc/gen.h: src/gen.h.proc src/in.txt src/other.txt" only
# because pconfigure splits the answer on whitespace that includes
# '\r'.  Kept, the first '\r' lands mid-line, make takes it as part of
# the name "src/in.txt\r", and the first make stops with no rule to
# build that.  A one-line answer can't see this: its '\r' is the last
# thing on the line, and make drops a CR there by itself.
#
# The build-time fragment is written a line per line of the answer, so
# each '\r' there is at the end of its own rule and make's own CRLF
# handling is what keeps it one path.  Editing each input in turn and
# seeing it reach the program is what checks both halves are watching
# both files, and the final make settling is what checks that neither
# names a file that doesn't exist.

mkdir -p src

printf 'src/in.txt\r\nsrc/other.txt\r\n' > src/list.txt
echo 1 > src/in.txt
echo 10 > src/other.txt

cat >Configfile <<EOF
LANGUAGES += c
GENERATE  += gen.h
BINARIES  += app
SOURCES   += app.c
EOF

cat >src/gen.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--deps)     cat src/list.txt ;;
--generate) echo "#define V ($(cat src/in.txt) + $(cat src/other.txt))" ;;
esac
EOF
chmod +x src/gen.h.proc

cat >src/app.c <<'EOF'
#include "gen.h"
#include <stdio.h>
int main(void) { printf("%d\n", V); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "11"

sleep 2
echo 2 > src/in.txt
make $MAKE_ARGS
test "$(./bin/app)" = "12"

sleep 2
echo 20 > src/other.txt
make $MAKE_ARGS
test "$(./bin/app)" = "22"

make $MAKE_ARGS > settled.out 2>&1
cat settled.out
grep -q "Nothing to be done" settled.out

exit 0
