#include "harness_start.bash"

# A bare '?' reaching the re-derived ".d" fragment, which is the path
# that actually matters and the one that used to be unguarded.
#
# generate-optional-dep-bad.bash refuses a bare '?' at configure time.
# That guard reads the answer PCONFIGURE got, and that is the snapshot:
# it is true when pconfigure runs and the whole reason the fragment
# exists is that it stops being true afterwards.  Editing a ".proc"
# script triggers the ".d" rule, not a reconfigure -- so a script that
# starts printing a bare '?' reaches the sed in that rule and nothing
# else, and the configure-time guard never sees it.  Measured against
# the draft this replaces, with this test's own script: the build
# SUCCEEDED, exit 0, nothing said, and the fragment grew
#
#     obj/proc/gen.h: $(wildcard )
#
# which expands to nothing -- so the input the script believes it
# declared ends up watched by nothing at all, which is this bug exactly,
# on the one path that exists because answers change after a configure.
# From a subproject the same line comes out "$(wildcard sub/)", which
# make resolves to the project's own directory: not a drop, but not the
# file the script named either.
#
# What does NOT happen is worth writing down, because an earlier draft of
# this comment claimed it did: no previously-declared mandatory input is
# lost.  The fragment ADDS prerequisites rather than replacing the rule's,
# so the configure-time snapshot goes on naming src/base.txt -- "make -p"
# reported it still there, and editing it still regenerated.  The damage
# is confined to the optional line.
#
# The guard is therefore made twice, from the same strings, and this is
# the control for the second one: against a fragment with no guard the
# make below SUCCEEDS, so the assertion that it FAILED is what catches it.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

GENERATE  += gen.h

BINARIES  += app
SOURCES   += app.c
EOF

# A mandatory input alongside, so that the fragment has something good in
# it for the refusal to leave alone.  A guard that rewrote the fragment
# and then complained would leave the graph in exactly the state it was
# complaining about, and a test whose fragment held only the bad line
# could not tell that apart from a clean refusal.
echo 1 > src/base.txt

# The answer changes when a marker appears, which is how a script's live
# answer differs from the snapshot without the script being rewritten
# mid-test -- and the marker's directory is watched, so creating it is
# what re-triggers the DEPS rule.
cat >src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     echo "src/base.txt"
            if test -f src/mark
            then echo "?"
            fi ;;
--generate) echo "#define BASE $(cat src/base.txt)" ;;
esac
EOF
chmod +x src/gen.h.proc

cat >src/app.c <<'EOF'
  #include "gen.h"
  #include <stdio.h>
int main(void) { printf("%d\n", BASE); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

timeout 60 make $MAKE_ARGS > first.out 2>&1 || { cat first.out; exit 1; }
cat first.out
test "$(./bin/app)" = "1"

# The fragment before anything goes wrong, so that what it loses later is
# attributable.
cat obj/proc/gen.h.d
grep -qxF 'obj/proc/gen.h: src/base.txt' obj/proc/gen.h.d

##############################################################################
# The live answer goes bad                                                   #
##############################################################################
sleep 2
touch src/mark

if timeout 60 make $MAKE_ARGS > second.out 2>&1
then
    cat second.out
    exit 1
fi
cat second.out

# It got as far as running the script, rather than failing earlier and
# proving nothing.
grep -q "^DEPS	gen.h$" second.out

# And it says the same four things the configure-time refusal says: which
# script, what the '?' means, what to write instead, and that printing
# nothing at all is allowed.  They are built from one set of strings in
# gen_proc.c++ precisely so that this test and
# generate-optional-dep-bad.bash cannot drift apart.
grep -q "src/gen.h.proc --deps' printed a '?' with no path after it" second.out
grep -q "optional input" second.out
grep -q "?src/thing" second.out
grep -q "nothing at all" second.out

# Nothing was written over the fragment.  A fragment that had been
# rewritten and then complained about would leave the graph in the broken
# state the complaint was about, which is the worst of both.
grep -qxF 'obj/proc/gen.h: src/base.txt' obj/proc/gen.h.d

if grep -q 'wildcard' obj/proc/gen.h.d
then
    exit 1
fi

# And no leftovers: neither the raw answer that was refused nor a
# half-written replacement.
if test -e obj/proc/gen.h.d.raw
then
    exit 1
fi
if test -e obj/proc/gen.h.d.tmp
then
    exit 1
fi

##############################################################################
# It keeps failing rather than failing once                                   #
##############################################################################
# This is the assertion a leftover ".raw" would break: with the refused
# answer still on disk, a second make could sed it into place and go
# green, which is a build that reports success exactly once per edit.
if timeout 60 make $MAKE_ARGS > third.out 2>&1
then
    cat third.out
    exit 1
fi
cat third.out
grep -q "^DEPS	gen.h$" third.out
grep -q "src/gen.h.proc --deps' printed a '?' with no path after it" third.out
grep -qxF 'obj/proc/gen.h: src/base.txt' obj/proc/gen.h.d

##############################################################################
# And it recovers when the script is fixed                                   #
##############################################################################
# The script writes the line the message told it to write.
sleep 2
cat >src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     echo "src/base.txt"
            if test -f src/mark
            then echo "?src/opt/answer.txt"
            fi ;;
--generate) echo "#define BASE $(cat src/base.txt)" ;;
esac
EOF
chmod +x src/gen.h.proc

timeout 60 make $MAKE_ARGS > fourth.out 2>&1 || { cat fourth.out; exit 1; }
cat fourth.out
grep -q "^DEPS	gen.h$" fourth.out

cat obj/proc/gen.h.d
grep -qxF 'obj/proc/gen.h: src/base.txt' obj/proc/gen.h.d
grep -qxF 'obj/proc/gen.h: $(foreach f,$(wildcard src/opt/answer.txt),$(if $(realpath $(f)),$(f),))' obj/proc/gen.h.d

timeout 60 make $MAKE_ARGS > fifth.out 2>&1 || { cat fifth.out; exit 1; }
cat fifth.out
grep -q "Nothing to be done" fifth.out

##############################################################################
# And "? " is refused here too                                                #
##############################################################################
# The guard that this replaces tested the LINE's length, so a '?' with a
# space after it sailed past it and recorded "$(wildcard  )" -- the same
# silent drop by a spelling that looked checked.  The fragment's guard
# judges the path empty after whitespace for the same reason the
# configure-time one does.
sleep 2
cat >src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     echo "src/base.txt"
            if test -f src/mark
            then printf '? \n'
            fi ;;
--generate) echo "#define BASE $(cat src/base.txt)" ;;
esac
EOF
chmod +x src/gen.h.proc

if timeout 60 make $MAKE_ARGS > sixth.out 2>&1
then
    cat sixth.out
    exit 1
fi
cat sixth.out
grep -q "src/gen.h.proc --deps' printed a '?' with no path after it" sixth.out
grep -qxF 'obj/proc/gen.h: src/base.txt' obj/proc/gen.h.d

exit 0
