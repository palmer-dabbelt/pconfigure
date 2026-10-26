#include "harness_start.bash"

# A header can be spelled for make, but the source the scan finds
# beside it is built, which puts its name on the left of a rule, into
# an object's name and bare into the compile recipe -- the places a
# SOURCES line's name goes, where a space or a '#' is refused at the
# Configfile line.  'my extra.c' went there unescaped and make stopped
# on a rule line nobody wrote.  pconfigure has to say so itself,
# pointing at the SOURCES line that led to it and naming both files.

mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES   += c

BINARIES    += app
SOURCES     += main.c
EOF2

cat >'src/my extra.h' <<'EOF2'
int extra(void);
EOF2

cat >'src/my extra.c' <<'EOF2'
int extra(void) { return 7; }
EOF2

cat >src/main.c <<'EOF2'
#include "my extra.h"
int main(void) { return extra(); }
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    exit 1
fi
cat out
grep -q "Configfile:4" out
grep -q "'src/main.c' reads 'src/my extra.h'" out
grep -q "'src/my extra.c', has a ' ' in its name" out
