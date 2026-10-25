#include "harness_start.bash"

# The same clean as the GENERATE consumer case, asked for one target
# by name.  "make bin/app" is an ordinary thing to type, and nothing
# about it should depend on "all" happening to list the generated
# header first: the consumer's object reads the header, so the header
# has to be made before the object is compiled.  When pdeps derives
# the fragment while the header is still missing it leaves it out, and
# the compile then runs with nothing having generated it.
export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src

cat >Configfile <<EOF
AUTORECONFIGURE = true

LANGUAGES += c

GENERATE  += gen.h

BINARIES  += app
SOURCES   += app.c
EOF

cat >src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     ;;
--generate) echo "#define ANSWER 6" ;;
esac
EOF
chmod +x src/gen.h.proc

cat >src/app.c <<'EOF'
  #include "gen.h"
  #include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS bin/app
test "$(./bin/app)" = "6"

make $MAKE_ARGS clean
test ! -e obj/proc/gen.h

make $MAKE_ARGS bin/app
test "$(./bin/app)" = "6"

exit 0
