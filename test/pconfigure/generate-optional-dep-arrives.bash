#include "harness_start.bash"

# The arrival of an optional input, which is the bug the '?' was added
# for.  A fixture script looked for a cross compiler another part of
# the tree builds later, found none at configure time, and wrote the
# empty answer -- correctly, since there was no compiler.  Then the
# compiler was built, four days later, and nothing reconsidered: the
# output encoded a verdict about the toolchain while the dependency
# graph held nothing about the toolchain, so the empty fixture kept its
# fresh mtime and make kept calling it up to date.  472 of 479 tests
# skipped for three days, and the suite scored every skip as a pass.
#
# What this pins that generate-late-input-appears.bash does not: that
# test covers an input arriving into a directory which already existed
# at configure time and was already named by the "--deps" answer, so
# the re-derived fragment is what hears it.  Here the input does not
# exist, its directory does not exist, and the answer named the file
# itself -- so what hears the arrival is the glob the configure wrote
# around a path it could not promise, re-expanded by the very next plain
# make.
#
# The arrival here is NEWER than the output, which is the case that
# works and is also the only case make promises.  An arrival that lands
# older than the output does not regenerate it, which is a real
# limitation of the '?' rather than a bug in this test, and
# generate-optional-dep-mtime-inverted.bash is where that is pinned.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

GENERATE  += gen.h

BINARIES  += app
SOURCES   += app.c
EOF

cat >src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     echo "?src/opt/answer.txt" ;;
--generate) if test -f src/opt/answer.txt
            then echo "#define ANSWER $(cat src/opt/answer.txt)"
            else echo "#define ANSWER 0"
            fi ;;
esac
EOF
chmod +x src/gen.h.proc

cat >src/app.c <<'EOF'
  #include "gen.h"
  #include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
timeout 60 make $MAKE_ARGS > first.out 2>&1 || { cat first.out; exit 1; }
cat first.out
test "$(./bin/app)" = "0"

timeout 60 make $MAKE_ARGS > settled.out 2>&1 || { cat settled.out; exit 1; }
cat settled.out
grep -q "Nothing to be done" settled.out

##############################################################################
# The optional input arrives, directory and all                              #
##############################################################################
sleep 2
mkdir -p src/opt
echo 42 > src/opt/answer.txt

timeout 60 make $MAKE_ARGS > second.out 2>&1 || { cat second.out; exit 1; }
cat second.out

# No reconfigure ran.  That is the point of the whole exercise: the
# incremental build is the one thing that may not ask for a
# reconfigure, and a fix that needs one fixes nothing.
if grep -q "^PCONFIGURE$" second.out
then
    exit 1
fi

# The output was regenerated and the consumers with it.
grep -q "^GEN	gen.h$" second.out
grep -q "^CC	app.c$" second.out
grep -q "^LD	app$" second.out

# And it regenerated to the answer the arrived file gives, which is
# the part the stale fixture got wrong for three days.
grep -q "define ANSWER 42" obj/proc/gen.h
test "$(./bin/app)" = "42"

timeout 60 make $MAKE_ARGS > third.out 2>&1 || { cat third.out; exit 1; }
cat third.out
grep -q "Nothing to be done" third.out

##############################################################################
# And then it changes, like any other input                                  #
##############################################################################
# An optional input that has arrived is an ordinary prerequisite from
# then on -- make treats a file it has no rule for and which is
# already there as simply up to date -- so a change to it has to be
# heard the way a change to a mandatory input is.
sleep 2
echo 7 > src/opt/answer.txt

timeout 60 make $MAKE_ARGS > fourth.out 2>&1 || { cat fourth.out; exit 1; }
cat fourth.out
grep -q "^GEN	gen.h$" fourth.out
grep -q "define ANSWER 7" obj/proc/gen.h
test "$(./bin/app)" = "7"

timeout 60 make $MAKE_ARGS > fifth.out 2>&1 || { cat fifth.out; exit 1; }
cat fifth.out
grep -q "Nothing to be done" fifth.out

##############################################################################
# And it can go away again                                                   #
##############################################################################
# The wildcard is re-expanded on every run, so a file that leaves stops
# being a prerequisite rather than becoming a missing one.  A build that
# breaks when an optional input is deleted is a build that made it
# mandatory by a slower route.
sleep 2
rm src/opt/answer.txt

timeout 60 make $MAKE_ARGS > sixth.out 2>&1 || { cat sixth.out; exit 1; }
cat sixth.out

if grep -q "No rule to make target" sixth.out
then
    exit 1
fi

# Nothing claims the deletion has to regenerate anything: the rule's
# prerequisite list got shorter, and a shorter list is not a newer
# one.  What is asked here is only that the build still works and
# still settles.
timeout 60 make $MAKE_ARGS > seventh.out 2>&1 || { cat seventh.out; exit 1; }
cat seventh.out
grep -q "Nothing to be done" seventh.out

exit 0
