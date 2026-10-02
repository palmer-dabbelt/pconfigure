#include "harness_start.bash"

# A dangling symlink matching an optional input's glob, which is the one
# state in which "$(wildcard P)" on its own turns a recoverable
# toolchain into an unbuildable tree.
#
# $(wildcard) answers out of the directory listing rather than by
# stat'ing what it found, so it reports a symlink whose target is gone
# as present.  make then holds a prerequisite that exists by name,
# cannot be stat'ed, and has no rule -- which is precisely the hard
# error the wildcard was chosen to avoid, arriving by the one route the
# wildcard does not cover.  Measured before the filter went in:
#
#     bare wildcard : [bin/aarch64-dangling-gcc bin/aarch64-real-gcc]
#     realpath filt : [ bin/aarch64-real-gcc]
#     $ make -f M2
#     make: *** No rule to make target 'bin/aarch64-dangling-gcc',
#     needed by 'out'.  Stop.
#
# This is not a corner case for the tree the convention was written for.
# EVERY name matching glade-vm's glob there is a symlink to one shared
# "toolchain-wrapper" binary, so any state in which the wrapper is gone
# and the links are not -- an interrupted buildroot, a half-cleaned host
# directory, a partially synced obj/ -- stops every target in the tree
# and not merely the generated one.  And it falsifies the convention's
# own promise in that promise's own terms: a file present but owned by
# nobody is supposed to be simply up to date.
#
# So each match is put through $(realpath), which stats and resolves and
# answers empty for a link with nothing on the end of it, and only the
# survivors are named.  What this test pins is that the build works with
# a dangling match present, that a live match beside it is still heard,
# and that the dangling one is heard the moment its target appears.
#
# This is the control for that filter: against a bare "$(wildcard)" the
# first make below stops with "No rule to make target", so the test
# fails at its first assertion rather than at a grep.

mkdir -p src obj/toolchain/bin

cat >Configfile <<EOF
LANGUAGES += c

GENERATE  += gen.h

BINARIES  += app
SOURCES   += app.c
EOF

# It counts what it can actually run, which is the honest question and
# also what makes the counting observable: a dangling symlink is matched
# by the shell's glob and by $(wildcard) alike, and "test -x" is what
# tells the two apart.
cat >src/gen.h.proc <<'EOF'
#!/bin/bash
n=0
for cc in obj/toolchain/bin/aarch64-*linux*-gcc
do
    if test -x "$cc"
    then
        n=$((n + 1))
    fi
done
case "$1" in
--deps)     echo "?obj/toolchain/bin/aarch64-*linux*-gcc" ;;
--generate) echo "#define CROSS_CC_COUNT $n" ;;
esac
EOF
chmod +x src/gen.h.proc

cat >src/app.c <<'EOF'
  #include "gen.h"
  #include <stdio.h>
int main(void) { printf("%d\n", CROSS_CC_COUNT); return 0; }
EOF

# The state an interrupted buildroot leaves: the links to the wrapper,
# and no wrapper.
ln -s toolchain-wrapper obj/toolchain/bin/aarch64-linux-gcc
ln -s toolchain-wrapper obj/toolchain/bin/aarch64-buildroot-linux-gnu-gcc
test ! -e obj/toolchain/bin/toolchain-wrapper
test -L obj/toolchain/bin/aarch64-linux-gcc

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# This is the assertion, and it is asked of the build rather than of the
# Makefile's text deliberately: with a bare "$(wildcard)" here the make
# below stops dead, and a reader of a future failure should see the
# wedge rather than a grep that missed.
timeout 60 make $MAKE_ARGS > first.out 2>&1 || { cat first.out; exit 1; }
cat first.out

if grep -q "No rule to make target" first.out
then
    exit 1
fi

# Nothing runnable, so nothing counted.
test "$(./bin/app)" = "0"

timeout 60 make $MAKE_ARGS > settled.out 2>&1 || { cat settled.out; exit 1; }
cat settled.out
grep -q "Nothing to be done" settled.out

# And the spelling that bought it, checked after the build for the same
# reason.  The filter wraps the glob rather than replacing it: the glob
# is still what finds the candidates, and $(realpath) is only what drops
# the ones that cannot be stat'ed.
grep -qxF 'obj/proc/gen.h: src/gen.h.proc $(foreach f,$(wildcard obj/toolchain/bin/aarch64-*linux*-gcc),$(if $(realpath $(f)),$(f),))' Makefile

##############################################################################
# A live match beside the dangling ones is still heard                       #
##############################################################################
# The filter must drop the dangling entries and nothing else.  A filter
# that threw the whole list away when any member of it was dangling would
# pass every assertion above and silently un-watch a toolchain that was
# there.
sleep 2
touch obj/toolchain/bin/aarch64-none-linux-gnu-gcc
chmod +x obj/toolchain/bin/aarch64-none-linux-gnu-gcc

timeout 60 make $MAKE_ARGS > second.out 2>&1 || { cat second.out; exit 1; }
cat second.out

if grep -q "No rule to make target" second.out
then
    exit 1
fi

grep -q "^GEN	gen.h$" second.out
grep -q "define CROSS_CC_COUNT 1" obj/proc/gen.h
test "$(./bin/app)" = "1"

timeout 60 make $MAKE_ARGS > third.out 2>&1 || { cat third.out; exit 1; }
cat third.out
grep -q "Nothing to be done" third.out

##############################################################################
# And the dangling links come good when their target arrives                 #
##############################################################################
# buildroot finishing is a wrapper appearing, and two names that were
# being filtered out become two real prerequisites with no reconfigure
# and no edit to the script's answer.
sleep 2
cat >obj/toolchain/bin/toolchain-wrapper <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x obj/toolchain/bin/toolchain-wrapper
test -x obj/toolchain/bin/aarch64-linux-gcc

timeout 60 make $MAKE_ARGS > fourth.out 2>&1 || { cat fourth.out; exit 1; }
cat fourth.out

if grep -q "^PCONFIGURE$" fourth.out
then
    exit 1
fi

grep -q "^GEN	gen.h$" fourth.out
grep -q "define CROSS_CC_COUNT 3" obj/proc/gen.h
test "$(./bin/app)" = "3"

timeout 60 make $MAKE_ARGS > fifth.out 2>&1 || { cat fifth.out; exit 1; }
cat fifth.out
grep -q "Nothing to be done" fifth.out

##############################################################################
# And a watched DIRECTORY that is a dangling symlink does not wedge either    #
##############################################################################
# The directories the .d fragment's rule watches go through the same
# filter and for the same reason, with one difference that makes them
# worse: that rule is an include, so a prerequisite make cannot stat
# there stops the Makefile from being read at all, and with it every
# target in the tree rather than only the generated one.  A half-cleaned
# host directory leaves exactly this -- the bin directory gone and the
# link to it still in place.
sleep 2
rm -rf obj/toolchain
mkdir -p obj/toolchain
ln -s nowhere obj/toolchain/bin
test -L obj/toolchain/bin
test ! -e obj/toolchain/bin

# A plain make is enough to catch this one.  The fragment is an include,
# so make tries to remake it on every run before it reads it, and an
# unstattable prerequisite on that rule stops the Makefile from being
# read at all -- "No rule to make target 'obj/toolchain/bin', needed by
# 'obj/proc/gen.h.d'" -- rather than waiting for something to ask for the
# generated file.
timeout 60 make $MAKE_ARGS > sixth.out 2>&1 || { cat sixth.out; exit 1; }
cat sixth.out

if grep -q "No rule to make target" sixth.out
then
    exit 1
fi

# Nothing is asked about regeneration here.  The compilers went away
# rather than arriving, so the rule's prerequisite list got shorter, and
# a shorter list is not a newer one -- the same thing
# generate-optional-dep-arrives.bash says about a deletion.
timeout 60 make $MAKE_ARGS > seventh.out 2>&1 || { cat seventh.out; exit 1; }
cat seventh.out
grep -q "Nothing to be done" seventh.out

# But the DEPS rule has to be able to RUN with the dangling directory
# watched, not merely be read past, so the script is touched to make it.
sleep 2
touch src/gen.h.proc

timeout 60 make $MAKE_ARGS > eighth.out 2>&1 || { cat eighth.out; exit 1; }
cat eighth.out

if grep -q "No rule to make target" eighth.out
then
    exit 1
fi

grep -q "^DEPS	gen.h$" eighth.out
grep -q "^GEN	gen.h$" eighth.out
grep -q "define CROSS_CC_COUNT 0" obj/proc/gen.h
test "$(./bin/app)" = "0"

timeout 60 make $MAKE_ARGS > ninth.out 2>&1 || { cat ninth.out; exit 1; }
cat ninth.out
grep -q "Nothing to be done" ninth.out

# And a configure run with the dangling directory already in place
# records the watch through the filter too, rather than only the build
# re-deriving it that way.  This is the snapshot half of the same site.
rm -rf obj/proc bin
$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
grep -qF 'obj/proc/gen.h.d: $(wildcard src/gen.h.proc) $(foreach f,$(wildcard obj/toolchain/bin),$(if $(realpath $(f)),$(f),))' Makefile

timeout 60 make $MAKE_ARGS > tenth.out 2>&1 || { cat tenth.out; exit 1; }
cat tenth.out

if grep -q "No rule to make target" tenth.out
then
    exit 1
fi

test "$(./bin/app)" = "0"

exit 0
