#include "harness_start.bash"

# The odd paths from generate-deps-path-with-hash-watched.bash and
# generate-deps-path-with-dollar-watched.bash, printed by a script that
# belongs to a subproject.  There every path a --deps line names gets
# the subproject's make variable put on its front, both in the rule
# pconfigure writes and in the sed that re-derives the fragment during
# the build, and that variable is a '$' which must stay an expansion
# while the '$' the script printed must not.  So the escaping has to
# happen to the script's words before the variable is added rather
# than after, or the variable is escaped along with them and the
# fragment names a file called "$(...)sub/src/...", which is not there.
#
# Two odd paths and an ordinary one on the same line, so that the words
# after a '#' are seen to survive as well as the word with the '#' in
# it.

mkdir -p sub/src

cat >Configfile <<'EOC'
SUBPROJECTS += sub
EOC

cat >sub/Configfile <<'EOC'
LANGUAGES   += c
GENERATE    += gen.h
BINARIES    += app
SOURCES     += main.c
EOC

cat >sub/src/gen.h.proc <<'EOC'
#!/bin/bash
case "$1" in
--deps)
    echo 'src/notes#1.txt src/cost$1.txt src/value.txt'
    ;;
--generate)
    echo "#define VALUE $(cat src/value.txt)$(cat 'src/notes#1.txt')$(cat 'src/cost$1.txt')"
    ;;
esac
EOC
chmod +x sub/src/gen.h.proc

echo 1 > sub/src/value.txt
echo 0 > 'sub/src/notes#1.txt'
echo 0 > 'sub/src/cost$1.txt'

cat >sub/src/main.c <<'EOC'
#include <stdio.h>
#include "gen.h"
int main(void) { printf("%d\n", VALUE); return 0; }
EOC

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./sub/bin/app)" = "100"

# Each of the three is watched, through the fragment the first make
# wrote as much as through the rule the configure wrote.
sleep 1
echo 2 > sub/src/value.txt
make $MAKE_ARGS
test "$(./sub/bin/app)" = "200"

sleep 1
echo 3 > 'sub/src/notes#1.txt'
make $MAKE_ARGS
test "$(./sub/bin/app)" = "230"

sleep 1
echo 4 > 'sub/src/cost$1.txt'
make $MAKE_ARGS
test "$(./sub/bin/app)" = "234"
