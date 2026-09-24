#include "harness_start.bash"

# A library's source changes; its archive is rebuilt; everything that
# links the archive relinks; and -- the half this test is really
# about -- nothing that merely *consumes* the library recompiles
# (taxonomy types 1 and E).  A relink is not a recompile: the
# consumer's object is as good as it ever was, and a build that
# recompiles it has propagated the change further than the dependency
# graph says it goes.
#
# The subproject shape is the point, not the scenery: the library
# lives behind SUBPROJECTS, with its own Configfile and its own object
# directory, which is where a change is most likely to be attributed
# to "the subproject's build" rather than to the one dependency graph
# everything shares.

mkdir -p src/top sub/src

cat >Configfile <<EOF
SUBPROJECTS   += sub

LANGUAGES     += c

BINARIES      += top
LINKOPTS      += -Lsub/lib
LINKOPTS      += -lsub
SOURCES       += top.c
EOF

cat >sub/Configfile <<EOF
LANGUAGES += c

LIBRARIES += libsub.a
SOURCES   += sub.c
EOF

cat >sub/src/sub.c <<'EOF'
int subval(void) { return 7; }
EOF

cat >src/top.c <<'EOF'
#include <stdio.h>
int subval(void);
int main(void) { printf("%d\n", subval()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS > first.out 2>&1
cat first.out
test "$(./bin/top)" = "7"

# A build that has nothing to do is the ordinary answer from here on,
# which is what makes the build after the edit mean something.
make $MAKE_ARGS > settled.out 2>&1
cat settled.out
grep -q "Nothing to be done" settled.out

##############################################################################
# The subproject library's source changes                                    #
##############################################################################
sleep 2
printf 'int subval(void) { return 8; }\n' > sub/src/sub.c

make $MAKE_ARGS > second.out 2>&1
cat second.out

# The library's source was recompiled and the archive rebuilt ...
grep -q "^CC	sub.c$" second.out
grep -q "^LD	libsub.a$" second.out

# ... the consumer relinked ...
grep -q "^LD	top$" second.out

# ... and its source did not recompile -- the relink is the whole
# propagation.
if grep -q "^CC	top.c$" second.out
then
    exit 1
fi

# The answer the binary gives is the new library's answer, the part a
# skipped relink would leave wrong.
test "$(./bin/top)" = "8"

exit 0
