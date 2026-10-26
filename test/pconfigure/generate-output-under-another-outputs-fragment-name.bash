#include "harness_start.bash"

# A GENERATE keeps "<name>.d" beside its output, and the manual says
# no other GENERATE may have that as its output.  A second GENERATE
# that puts its output UNDER that name -- "gen.h.d/inner.h" -- needs
# obj/proc/gen.h.d to be a directory while the first wants it to be
# its dependency fragment, which is the same fight over one path with
# a slash in the way.  The scratch-file check used to compare whole
# paths only and let it through, to fail later with "obj/proc/gen.h.d:
# Is a directory".  It is refused like "GENERATE += gen.h.d" is,
# naming the line it collides with.

mkdir -p src/gen.h.d

cat >Configfile <<EOF
LANGUAGES += c
GENERATE  += gen.h
GENERATE  += gen.h.d/inner.h
BINARIES  += app
SOURCES   += app.c
EOF

cat >src/gen.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--generate) echo "#define A 1" ;;
esac
EOF
cat >src/gen.h.d/inner.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--generate) echo "#define B 2" ;;
esac
EOF
chmod +x src/gen.h.proc src/gen.h.d/inner.h.proc

cat >src/app.c <<'EOF'
#include "gen.h"
#include "gen.h.d/inner.h"
int main(void) { return A + B - 3; }
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS >configure.out 2>&1
then
    cat configure.out
    exit 1
fi
cat configure.out

head -n1 configure.out | grep -qF "Configfile:3 'GENERATE += gen.h.d/inner.h'"
grep -qF "Configfile:2 'GENERATE += gen.h'" configure.out
grep -qF "'obj/proc/gen.h.d' is the dependency fragment" configure.out

# Refused before the second script ran.
test ! -e obj/proc/gen.h.d/inner.h

exit 0
