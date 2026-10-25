#include "harness_start.bash"

# One generated header read by a C program and a C++ program.  The
# output directory is on both languages' include paths, and both
# objects depend on the header, so an edit to the script's input
# rebuilds both programs -- a dependency recorded by only one of the
# two languages would leave the other one printing the old answer.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c
LANGUAGES += c++

GENERATE  += gen.h

BINARIES  += cxxapp
SOURCES   += main.c++

BINARIES  += capp
SOURCES   += main.c
EOF

echo 4 > src/answer.txt

cat >src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     echo "src/answer.txt" ;;
--generate) echo "#define ANSWER $(cat src/answer.txt)" ;;
esac
EOF
chmod +x src/gen.h.proc

cat >src/main.c <<'EOF'
  #include "gen.h"
  #include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

cat >src/main.c++ <<'EOF'
  #include "gen.h"
  #include <cstdio>
int main(void) { std::printf("%d\n", ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

make $MAKE_ARGS
test "$(./bin/capp)" = "4"
test "$(./bin/cxxapp)" = "4"

sleep 2
echo 6 > src/answer.txt
make $MAKE_ARGS > again.out 2>&1
cat again.out
test "$(./bin/capp)" = "6"
test "$(./bin/cxxapp)" = "6"

exit 0
