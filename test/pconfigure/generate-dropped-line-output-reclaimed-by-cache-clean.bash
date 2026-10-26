#include "harness_start.bash"

# Removing a GENERATE line leaves its last output in obj/proc, and a
# source that still includes it goes on compiling against it -- make
# clean doesn't know the file any more either.  make cache-clean is
# the documented answer to "what the build no longer knows how to
# make", so it has to take the output and its dependency fragment.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c
GENERATE  += gen.h
BINARIES  += app
SOURCES   += app.c
EOF

cat >src/gen.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--generate) echo "#define V 1" ;;
esac
EOF
chmod +x src/gen.h.proc

cat >src/app.c <<'EOF'
#include "gen.h"
#include <stdio.h>
int main(void) { printf("%d\n", V); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test -f obj/proc/gen.h

cat >Configfile <<EOF
LANGUAGES += c
BINARIES  += app
SOURCES   += app.c
EOF
rm src/gen.h.proc

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS cache-clean
find obj
test ! -e obj/proc/gen.h
test ! -e obj/proc/gen.h.d

# After that the build has to stop over gen.h rather than quietly
# succeed.  Today it is make that stops, not the compiler: the second
# configure scanned app.c while obj/proc/gen.h was still on disk, so
# the Makefile names it as a prerequisite of app.c's object, and with
# the file gone and no rule to build it make reports "No rule to make
# target 'obj/proc/gen.h'".  A pconfigure that rescanned would get
# the compiler's missing-header error instead, which is just as right,
# so all this asks is that the build fails and that it is gen.h it
# fails over -- not something else the cache-clean took with it, and
# not the deleted gen.h.proc, which is why the match stops at the name.
make $MAKE_ARGS clean
if make $MAKE_ARGS > stale.out 2>&1
then
    cat stale.out
    exit 1
fi
cat stale.out
grep -Eq "gen\.h([^.[:alnum:]]|$)" stale.out

exit 0
