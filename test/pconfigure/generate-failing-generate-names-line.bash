#include "harness_start.bash"

# A GENERATE whose script fails while pconfigure runs it is a fatal
# error, and like every other fatal error it has to point at the
# Configfile line that asked for the script.  What came out was the
# whole recipe pconfigure had handed to system() and the word
# "failed", which names neither the line nor the script on its own.

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
--generate) exit 3 ;;
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

# It names the script and the run that failed rather than the recipe
# that wrapped it, which a reader never wrote and has to pick apart to
# find the script in.
grep -q "error: 'src/gen.h.proc --generate' failed" configure.out
if grep -q "system(" configure.out
then
    exit 1
fi

# The failed run leaves nothing behind, at configure time as at make
# time, or the next pconfigure would find a target and never run the
# script again.
test ! -e obj/proc/gen.h
test ! -e obj/proc/gen.h.tmp
test ! -e Makefile

exit 0
