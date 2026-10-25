#include "harness_start.bash"

# A GENERATE whose script is not there at all is the commonest way to
# get one wrong -- a typo in the name, or the script left out of a
# commit -- and the fatal error has to say which line asked for it and
# which file it looked for.  What came out was the shell's "No such
# file or directory" and "failed with status 32512", with no
# Configfile line in it.

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

if $PTEST_BINARY $PCONFIGURE_ARGS >configure.out 2>&1
then
    cat configure.out
    exit 1
fi
cat configure.out

# It says which line asked for the script, so the reader knows where
# to look without having to work out which GENERATE owns the name.
grep -q "^./Configfile:3 'GENERATE += gen.h'$" configure.out

# It names the file it looked for and says what to do about it, rather
# than handing the shell's "not found" on with an exit code nobody
# recognizes.
grep -q "error: GENERATE += gen.h runs src/gen.h.proc, which does not exist$" configure.out
if grep -q "32512" configure.out
then
    exit 1
fi
test ! -e Makefile

exit 0
