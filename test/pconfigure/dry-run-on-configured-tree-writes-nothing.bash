#include "harness_start.bash"

# "make -n" on a configured tree prints the build without doing any of
# it.  Every rule pconfigure writes that isn't a makefile make has to
# read -- the link-inputs records, the BASH recipe records, the check
# stamp and scope, the install copies, the deletions clean, distclean,
# uninstall and cache-clean make -- has to stay printed and not run,
# both on a tree that has only been configured and on one where all of
# it has been built, so that each goal has something it would do.

mkdir -p src include test/hello

cat >Configfile <<'EOF'
LANGUAGES += c
LANGUAGES += bash

LIBRARIES += libx.so
SOURCES   += x.c

BINARIES  += hello
DEPLIBS   += x
SOURCES   += hello.c
TESTSRC   += runs.bash

BINARIES  += script
SOURCES   += script.bash

HEADERS   += x.h
EOF

cat >include/x.h <<'EOF'
int x(void);
EOF

cat >src/x.c <<'EOF'
int x(void) { return 0; }
EOF

cat >src/hello.c <<'EOF'
#include <x.h>
int main(void) { return x(); }
EOF

cat >src/script.bash <<'EOF'
echo script
EOF

cat >test/hello/runs.bash <<'EOF'
"$PTEST_BINARY"
EOF

$PTEST_BINARY $PCONFIGURE_ARGS

# A snapshot of every path in the tree with each file's size and
# modification time, so a dry run that rewrites a file in place is
# caught as well as one that adds or removes one.  Directories are
# listed by name only: what this test writes into lists/ changes the
# times of the directories above it, and a dry run that touched a
# directory without changing what's in it isn't a write anybody sees.
mkdir lists
snapshot() {
    find . -path ./lists -prune \
        -o -type d -printf '%p\n' \
        -o -printf '%p %s %T@\n' | sort
}

# What a fresh configure left; nothing below may change it.
snapshot > lists/before

for goal in all check install clean distclean uninstall cache-clean
do
    make $MAKE_ARGS -n $goal DESTDIR="$tempdir/stage" > lists/dry.out
    snapshot > lists/after
    diff lists/before lists/after
done

# Now with everything built: a dry run of any goal, the ones that
# delete included, leaves the tree exactly as it was.  Sleep first so
# anything a dry run rewrote would get a different time.
make $MAKE_ARGS
make $MAKE_ARGS check
make $MAKE_ARGS install DESTDIR="$tempdir/stage"
test -x stage/usr/local/bin/hello
test -f check/hello/runs.bash
sleep 1
snapshot > lists/built

for goal in all check install clean distclean uninstall cache-clean
do
    make $MAKE_ARGS -n $goal DESTDIR="$tempdir/stage" > lists/dry.out
    snapshot > lists/after
    diff lists/built lists/after
done

exit 0
