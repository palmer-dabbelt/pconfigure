#include "harness_start.bash"

# "-iquote" and "-idirafter" name include directories just as "-I"
# and "-isystem" do, and a subproject writes them from its own
# directory for the same reason.  Both spellings gcc takes are here:
# "-iquoteinc" with the directory stuck on, and "-idirafter more" with
# it as the next word.
#
# Under AUTORECONFIGURE the headers a source reads are worked out by
# pdeps while make runs, from the options pconfigure handed it, so
# this checks that it reads these flags the way pconfigure does --
# and that the rerooted directories still mean the subproject's own
# when the build is run from inside it, where the subproject's
# directory is spelled with nothing on the front.

mkdir -p a/src a/inc a/more

cat >Configfile <<EOF
AUTORECONFIGURE = true

SUBPROJECTS += a
EOF

cat >a/Configfile <<EOF
AUTORECONFIGURE = true

LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -iquoteinc
COMPILEOPTS += -idirafter more
SOURCES     += main.c
EOF

cat >a/inc/quoted.h <<'EOF'
#define QUOTED 1
EOF

cat >a/more/after.h <<'EOF'
#define AFTER 10
EOF

cat >a/src/main.c <<'EOF'
#include <stdio.h>
#include "quoted.h"
#include <after.h>
int main(void) { printf("%d\n", QUOTED + AFTER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat a/obj/Makefile.a
make $MAKE_ARGS
test "$(./a/bin/app)" = "11"

# Both headers are prerequisites of the object, so editing either one
# rebuilds it.
sleep 2
cat >a/inc/quoted.h <<'EOF'
#define QUOTED 2
EOF

make $MAKE_ARGS
test "$(./a/bin/app)" = "12"

sleep 2
cat >a/more/after.h <<'EOF'
#define AFTER 20
EOF

make $MAKE_ARGS
test "$(./a/bin/app)" = "22"

# And the same from inside the subproject, where the rerooted
# directories have to come out without the subproject's name on the
# front.
(cd a && $PTEST_BINARY $PCONFIGURE_ARGS)
(cd a && timeout 60 make $MAKE_ARGS)
test "$(cd a && ./bin/app)" = "22"

sleep 2
cat >a/inc/quoted.h <<'EOF'
#define QUOTED 3
EOF
cat >a/more/after.h <<'EOF'
#define AFTER 30
EOF

(cd a && timeout 60 make $MAKE_ARGS)
test "$(cd a && ./bin/app)" = "33"
