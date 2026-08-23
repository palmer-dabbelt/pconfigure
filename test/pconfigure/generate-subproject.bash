#include "harness_start.bash"

mkdir -p sub/src

# A GENERATE inside a subproject, which is the only place the script
# has to be run from somewhere other than where pconfigure is
# standing.
cat >Configfile <<EOF
SUBPROJECTS += sub
EOF

cat >sub/Configfile <<EOF
LANGUAGES += c

GENERATE  += gen.h
BINARIES  += test
SOURCES   += test.c
EOF

# It reads a file of its own, so that "--deps" has something to print
# and the path it prints gets checked too.
cat >sub/src/answer.txt <<EOF
42
EOF

cat >sub/src/gen.h.proc <<"EOF"
#!/bin/bash
case "$1" in
--deps)     echo "src/answer.txt" ;;
--generate) echo "#define ANSWER $(cat src/answer.txt)" ;;
esac
EOF
chmod +x sub/src/gen.h.proc

cat >sub/src/test.c <<EOF
  #include <stdio.h>
  #include "gen.h"
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
cat sub/Makefile

# The script is one program with a path, and the "cd" in front of it
# is not part of that path: quoting the whole compound sends the shell
# looking for a program named "cd sub/. && src/gen.h.proc", which it
# does not find and never will.
grep -q "cd .*sub.* && src/gen.h.proc --generate" sub/Makefile

# What "--deps" printed is relative to the project that owns the
# script, so it lands in the Makefile with that project on the front.
grep -q "obj/proc/gen.h: .*src/gen.h.proc .*src/answer.txt" sub/Makefile

make $MAKE_ARGS
test "$(./sub/bin/test)" = "42"

# The generated file is really generated, rather than the build
# happening to work without it.
grep -q "define ANSWER 42" sub/obj/proc/gen.h

# Changing what the script reads regenerates it, since "--deps" said
# so and that is the whole point of asking.
sleep 2
echo 7 > sub/src/answer.txt
make $MAKE_ARGS
test "$(./sub/bin/test)" = "7"

# The subproject still builds on its own.  The recipe says "the
# project this belongs to" rather than "sub", so it means the right
# directory from either place -- a hard-coded "cd sub" is a directory
# that only exists when make was run in the parent.
cd sub
rm -rf obj bin
make $MAKE_ARGS
test "$(./bin/test)" = "7"
cd ..

exit 0
