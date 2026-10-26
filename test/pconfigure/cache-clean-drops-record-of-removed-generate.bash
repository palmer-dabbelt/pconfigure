#include "harness_start.bash"

# Beside every GENERATE's dependency fragment the configure leaves a
# record of the recipe that writes the fragment, and "make cache-clean"
# has to spare it, since the Makefile names no rule for it and a
# missing record costs the next configure a "--deps" run.  But only the
# record of a GENERATE that is still in the Configfile is worth
# sparing: once a GENERATE is deleted its output and fragment are
# reclaimed like any other stale file, and nothing will ever read its
# record again.  Sparing that one too would leave it in the object
# directory for ever, which is exactly what cache-clean is for.
#
# Two GENERATEs, so that one cache-clean is held to both halves at
# once: the dropped one's record goes, the live one's stays.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c
GENERATE  += kept.h
GENERATE  += gone.h
BINARIES  += app
SOURCES   += app.c
EOF

for name in kept gone
do
    cat >src/$name.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--generate) echo "#define V 1" ;;
esac
EOF
    chmod +x src/$name.h.proc
done

cat >src/app.c <<'EOF'
#include "kept.h"
#include <stdio.h>
int main(void) { printf("%d\n", V); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test -f obj/proc/gone.h
test -f obj/proc/gone.h.d-context
test -f obj/proc/kept.h.d-context

cat >Configfile <<EOF
LANGUAGES += c
GENERATE  += kept.h
BINARIES  += app
SOURCES   += app.c
EOF
rm src/gone.h.proc

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS cache-clean
find obj
test ! -e obj/proc/gone.h
test ! -e obj/proc/gone.h.d
test ! -e obj/proc/gone.h.d-context
test -f obj/proc/kept.h.d-context

exit 0
