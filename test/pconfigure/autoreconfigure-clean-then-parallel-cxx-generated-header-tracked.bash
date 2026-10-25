#include "harness_start.bash"

# The C++ side of the generated-header-after-clean case, built in
# parallel.  The fragment for a C++ source is derived by the same
# pdeps, so the header the build generates has to be in it no matter
# which of the two make got to first: with two jobs either order is
# fair game, and only one of them would find the header on disk.
export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src

cat >Configfile <<EOF
AUTORECONFIGURE = true

LANGUAGES += c++

GENERATE  += gen.h++

BINARIES  += app
SOURCES   += app.c++
EOF

echo 3 > src/answer.txt

cat >src/gen.h++.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     echo "src/answer.txt" ;;
--generate) echo "#define ANSWER $(cat src/answer.txt)" ;;
esac
EOF
chmod +x src/gen.h++.proc

cat >src/app.c++ <<'EOF'
  #include "gen.h++"
  #include <cstdio>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "3"

make $MAKE_ARGS clean
make $MAKE_ARGS -j2
test "$(./bin/app)" = "3"

sleep 2
echo 5 > src/answer.txt
make $MAKE_ARGS -j2
test "$(./bin/app)" = "5"

exit 0
