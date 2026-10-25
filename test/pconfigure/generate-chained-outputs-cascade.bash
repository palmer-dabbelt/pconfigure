#include "harness_start.bash"

# One GENERATE reading another's output: b.h is made from a.h, which
# is made from an input file.  The second script names obj/proc/a.h in
# its "--deps", which is a file the Makefile has a rule for, so make
# orders the two and an edit to the input has to flow through both
# outputs into the binary.  The scripts are listed in the order they
# have to run in, since pconfigure also runs them once while it
# configures and does that in Configfile order.
#
# obj/proc is the directory a GENERATE's output lands in, and it is
# deliberately not watched for new files; naming a file in it is still
# a dependency on that file, which is what this pins.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

GENERATE  += a.h
GENERATE  += b.h

BINARIES  += app
SOURCES   += app.c
EOF

echo 4 > src/answer.txt

cat >src/a.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     echo "src/answer.txt" ;;
--generate) echo "#define A $(cat src/answer.txt)" ;;
esac
EOF
chmod +x src/a.h.proc

cat >src/b.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     echo "obj/proc/a.h" ;;
--generate) sed 's/define A /define ANSWER /' obj/proc/a.h ;;
esac
EOF
chmod +x src/b.h.proc

cat >src/app.c <<'EOF'
  #include "b.h"
  #include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

make $MAKE_ARGS
test "$(./bin/app)" = "4"

sleep 2
echo 8 > src/answer.txt
make $MAKE_ARGS > again.out 2>&1
cat again.out
grep -q "^GEN	a.h$" again.out
grep -q "^GEN	b.h$" again.out
test "$(./bin/app)" = "8"

# And from nothing at all, in parallel, the order still holds.
make $MAKE_ARGS clean
make $MAKE_ARGS -j2
test "$(./bin/app)" = "8"

make $MAKE_ARGS > settled.out 2>&1
cat settled.out
if grep -q "^GEN" settled.out
then
    exit 1
fi

exit 0
