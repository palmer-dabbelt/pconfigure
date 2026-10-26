#include "harness_start.bash"

# A GENERATE keeps a record of the recipe that writes its output in the
# object directory, and for an output that is itself in the object
# directory that record sits right beside it: "gen.h" is recorded in
# "gen.h.recipe-inputs".  A second GENERATE of that name would have
# every configure write the record over its output, so it is refused
# like the other names a GENERATE keeps for itself.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

GENERATE  += gen.h
GENERATE  += gen.h.recipe-inputs

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

cat >src/gen.h.recipe-inputs.proc <<'EOF'
#!/bin/bash
case "$1" in
--generate) echo "just some text" ;;
esac
EOF
chmod +x src/gen.h.recipe-inputs.proc

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

head -n1 configure.out | grep -qF "Configfile:4 'GENERATE += gen.h.recipe-inputs'"
grep -qF "Configfile:3 'GENERATE += gen.h'" configure.out
grep -qF "record of the recipe that writes the output" configure.out

exit 0
