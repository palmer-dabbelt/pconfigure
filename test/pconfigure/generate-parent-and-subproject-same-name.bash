#include "harness_start.bash"

# A parent and a subproject that each generate a "gen.h" generate two
# different files: each project's output lands in its own object
# directory, and each project's sources see their own.  A shared
# output directory, or an include path that leaked across the
# boundary, would have one of the two binaries print the other's
# answer.

mkdir -p src sub/src

cat >Configfile <<EOF
LANGUAGES   += c

GENERATE    += gen.h

BINARIES    += top
SOURCES     += top.c

SUBPROJECTS += sub
EOF

cat >sub/Configfile <<EOF
LANGUAGES += c

GENERATE  += gen.h

BINARIES  += inner
SOURCES   += inner.c
EOF

for d in . sub
do
    test "$d" = . && n=1 || n=2
    cat >$d/src/gen.h.proc <<EOF
#!/bin/bash
case "\$1" in
--generate) echo "#define ANSWER $n" ;;
esac
EOF
    chmod +x $d/src/gen.h.proc
done

cat >src/top.c <<'EOF'
  #include "gen.h"
  #include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF
cp src/top.c sub/src/inner.c

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

make $MAKE_ARGS
test "$(./bin/top)" = "1"
test "$(./sub/bin/inner)" = "2"
grep -q "ANSWER 1" obj/proc/gen.h
grep -q "ANSWER 2" sub/obj/proc/gen.h

# Editing one script regenerates that project's output and rebuilds
# that project's binary, and leaves the other alone.
sleep 2
sed -i 's/ANSWER 2/ANSWER 3/' sub/src/gen.h.proc
make $MAKE_ARGS > again.out 2>&1
cat again.out
test "$(./bin/top)" = "1"
test "$(./sub/bin/inner)" = "3"
grep -q "^CC	inner.c$" again.out
if grep -q "top.c" again.out
then
    exit 1
fi

exit 0
