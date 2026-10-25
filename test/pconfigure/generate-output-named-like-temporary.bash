#include "harness_start.bash"

# A GENERATE writes its output to "<name>.tmp" first and then moves it
# into place.  A second GENERATE whose output is called "gen.h.tmp" is
# therefore the first one's temporary: every regeneration of gen.h
# moves (or deletes) gen.h.tmp out from under its own rule, and with
# make -j2 every other build used to finish with gen.h.tmp missing.
# Nothing said anything about it, at configure time or after.
#
# The two cannot share the file, so the second line is refused,
# pointing at both lines.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

GENERATE  += gen.h
GENERATE  += gen.h.tmp

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

cat >src/gen.h.tmp.proc <<'EOF'
#!/bin/bash
case "$1" in
--generate) echo "just some text" ;;
esac
EOF
chmod +x src/gen.h.tmp.proc

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
head -n1 configure.out | grep -qF "Configfile:4 'GENERATE += gen.h.tmp'"
grep -qF "Configfile:3 'GENERATE += gen.h'" configure.out
grep -qF "temporary" configure.out

exit 0
