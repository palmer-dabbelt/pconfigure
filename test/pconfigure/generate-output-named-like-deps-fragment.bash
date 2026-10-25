#include "harness_start.bash"

# Every GENERATE keeps files of its own beside its output in obj/proc:
# "<name>.d", the dependency fragment the Makefile includes, with
# "<name>.d.raw", "<name>.d.tmp" and "<name>.d-context" alongside it,
# and "<name>.tmp", where the output is written before it is moved into
# place.  A second GENERATE whose output is called "gen.h.d" therefore
# lands on the first one's fragment: two rules for one file, which
# pconfigure used to find out about deep inside the Makefile writer and
# abort on with exit status 134 and nothing on stderr at all.
#
# The two cannot both have that file, so the line that asked for the
# second one is refused, by line number, along with the line it
# collides with and what to write instead.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

GENERATE  += gen.h
GENERATE  += gen.h.d

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

cat >src/gen.h.d.proc <<'EOF'
#!/bin/bash
case "$1" in
--generate) echo "just some text" ;;
esac
EOF
chmod +x src/gen.h.d.proc

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
head -n1 configure.out | grep -qF "Configfile:4 'GENERATE += gen.h.d'"
grep -qF "Configfile:3 'GENERATE += gen.h'" configure.out
grep -qF "dependency fragment" configure.out

# Refused before anything ran: the second script never got as far as
# writing the file it was refused for.
test ! -e obj/proc/gen.h.d

exit 0
