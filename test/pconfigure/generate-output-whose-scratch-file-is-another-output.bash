#include "harness_start.bash"

# The same collision as an output named after another GENERATE's
# fragment, written the other way round: "gen.h.d-context" is asked for
# first, and the GENERATE below it would keep its recipe record in that
# very file.  Which line is refused cannot depend on which of the two
# was written first, or half of these collisions would go through --
# so it is the later line that is refused, and it names the earlier.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

GENERATE  += gen.h.d-context
GENERATE  += gen.h

BINARIES  += app
SOURCES   += app.c
EOF

cat >src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--generate) echo "#define ANSWER 3" ;;
esac
EOF
chmod +x src/gen.h.proc

cat >src/gen.h.d-context.proc <<'EOF'
#!/bin/bash
case "$1" in
--generate) echo "just some text" ;;
esac
EOF
chmod +x src/gen.h.d-context.proc

cat >src/app.c <<'EOF'
  #include "gen.h"
  #include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS >configure.out 2>&1
then
    cat configure.out
    exit 1
fi
cat configure.out

# The refused line comes first, the way every other refusal points at
# the line it refuses; the line it collides with is named after it.
head -n1 configure.out | grep -qF "Configfile:4 'GENERATE += gen.h'"
grep -qF "Configfile:3 'GENERATE += gen.h.d-context'" configure.out
grep -qF "record of the dependency fragment's recipe" configure.out

exit 0
