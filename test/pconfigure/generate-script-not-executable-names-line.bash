#include "harness_start.bash"

# A GENERATE script that exists but was committed without its execute
# bit is run by pconfigure and refused by the shell.  The fatal error
# has to say which Configfile line asked for it, and what came out was
# the shell's "Permission denied" and a raw wait() status.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

GENERATE  += gen.h

BINARIES  += app
SOURCES   += app.c
EOF

cat >src/app.c <<'EOF'
  #include "gen.h"
int main(void) { return 0; }
EOF

cat >src/gen.h.proc <<'EOF'
#!/bin/bash
echo "int x;"
EOF
chmod -x src/gen.h.proc

if $PTEST_BINARY $PCONFIGURE_ARGS >configure.out 2>&1
then
    cat configure.out
    exit 1
fi
cat configure.out

# It says which line asked for the script, so the reader knows where
# to look without having to work out which GENERATE owns the name.
grep -q "^./Configfile:3 'GENERATE += gen.h'$" configure.out

# It says what is wrong with the file and what fixes it.
grep -q "error: src/gen.h.proc is there but is not executable$" configure.out
grep -q "chmod +x src/gen.h.proc" configure.out
if grep -q "32256" configure.out
then
    exit 1
fi
test ! -e Makefile

exit 0
