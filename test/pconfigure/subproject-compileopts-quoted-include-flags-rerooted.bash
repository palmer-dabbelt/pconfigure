#include "harness_start.bash"

# A subproject's "-I" and "-include" get its directory put on the
# front, and a quote that opens before the flag is still the shell's:
# '-Iinc' is -Iinc.  Matched as written, those words started with a
# quote rather than a flag and went to the compiler untouched, so it
# looked for inc/ and forced.h at the top of the tree while the
# header scan, which does take the quotes off, looked in the
# subproject.  The top has a forced.h and an inc/value.h of its own
# here so that reading the wrong ones is a wrong answer rather than
# just a missing file.
#
# An absolute directory quoted after the flag, -I"/.../abs", is the
# other half of the same mistake: rerooted as written it starts with
# a quote rather than a '/', so it looked relative and got the
# subproject's directory put on the front of it.
#
# All of it has to hold from inside the subproject too, where the
# subproject's directory is spelled with nothing on the front.

mkdir -p a/src a/inc abs inc

cat >Configfile <<'EOF'
SUBPROJECTS += a
EOF

cat >forced.h <<'EOF'
#define FORCED 100
EOF

cat >inc/value.h <<'EOF'
#define VALUE 100
EOF

cat >a/Configfile <<EOF
LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += '-Iinc'
COMPILEOPTS += '-includeforced.h'
COMPILEOPTS += -I"$(pwd)/abs"
SOURCES     += main.c
EOF

cat >a/forced.h <<'EOF'
#define FORCED 1
EOF

cat >a/inc/value.h <<'EOF'
#define VALUE 10
EOF

cat >abs/other.h <<'EOF'
#define OTHER 1000
EOF

cat >a/src/main.c <<'EOF'
#include <stdio.h>
#include <value.h>
#include <other.h>
int main(void) { printf("%d\n", FORCED + VALUE + OTHER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat a/obj/Makefile.a
make $MAKE_ARGS
test "$(./a/bin/app)" = "1011"

(cd a && $PTEST_BINARY $PCONFIGURE_ARGS)
(cd a && timeout 60 make $MAKE_ARGS)
test "$(cd a && ./bin/app)" = "1011"
