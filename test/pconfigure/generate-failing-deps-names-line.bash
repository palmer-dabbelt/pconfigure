#include "harness_start.bash"

# A GENERATE whose "--deps" fails while pconfigure asks it is a fatal
# error, and like every other fatal error it has to point at the
# Configfile line that asked for the script.  What came out was the
# command line and a raw wait() status -- "failed with status 512" for
# a script that exited 2 -- with no line and no exit code a reader
# would recognize.

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
case "$1" in
--deps)     exit 2 ;;
--generate) echo "int x;" ;;
esac
EOF
chmod +x src/gen.h.proc

if $PTEST_BINARY $PCONFIGURE_ARGS >configure.out 2>&1
then
    cat configure.out
    exit 1
fi
cat configure.out

# It says which line asked for the script, so the reader knows where
# to look without having to work out which GENERATE owns the name.
grep -q "^./Configfile:3 'GENERATE += gen.h'$" configure.out

# And it says how the script failed in the terms the script was written
# in: the exit code it chose, rather than wait()'s encoding of it, which
# is that code shifted left by eight.
grep -q "error: 'src/gen.h.proc --deps' exited with status 2$" configure.out
if grep -q "512" configure.out
then
    exit 1
fi
test ! -e Makefile

exit 0
