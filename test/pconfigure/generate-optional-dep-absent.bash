#include "harness_start.bash"

# A script that reads a file only if it is there -- a cross compiler
# some other part of the tree builds later on, most often -- has an
# input it cannot name.  Naming it outright breaks every build that
# does not have one yet, because a prerequisite that is absent and
# that no rule builds is a hard error rather than a shrug, and it is a
# hard error for a build that was not even asking for the generated
# file.  So the scripts in that position said nothing about the input
# at all, which bought the build but cost the dependency graph: the
# generated output then encoded a verdict about something the graph
# held nothing about, and nothing ever reconsidered it.
#
# A "--deps" line may therefore begin with a '?' to say the input is
# optional, and pconfigure records that line wrapped in a filter --
# "$(wildcard)" for the glob, and a "$(realpath)" test over what it
# matched so that a dangling symlink is not counted as present -- rather
# than naming it.  What this test pins is the half of that convention
# that has to work while the file is still missing: the configure
# succeeds, the build succeeds, and the build settles, with a
# prerequisite in the rule that names a file nothing can build.
# generate-optional-dep-arrives.bash pins the other half, the arrival,
# and generate-optional-dep-dangling-symlink.bash pins the filter.

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

# Nothing in the Makefile builds the optional input, which is the whole
# difficulty: this is the shape that a plain prerequisite turns into
# "No rule to make target".
if grep -q '^src/opt/answer.txt:' Makefile
then
    exit 1
fi

# The build is asked before the Makefile is read, deliberately, so that
# a failure here is the behaviour rather than the spelling: without the
# wildcard this make stops with "No rule to make target '?src/opt/...'".
timeout 60 make $MAKE_ARGS > first.out 2>&1 || { cat first.out; exit 1; }
cat first.out

# Said out loud rather than left to the exit status, because this is
# the error the wrapper exists to prevent and a reader of a future
# failure should see it named.
if grep -q "No rule to make target" first.out
then
    exit 1
fi

test "$(./bin/app)" = "0"

# The fragment re-derived during the build wraps it too.  It has to:
# that answer is the script's live one, and a line reaching the
# fragment bare is the same hard error by a later route.
cat obj/proc/gen.h.d
grep -qxF 'obj/proc/gen.h: $(foreach f,$(wildcard src/opt/answer.txt),$(if $(realpath $(f)),$(f),))' obj/proc/gen.h.d

# Now the spelling that bought all of that, which is worth pinning
# separately because it is what a future change would break quietly.
# The configure-time snapshot names the optional input through a
# wildcard, and the '?' is not part of the path.
grep -qxF 'obj/proc/gen.h: src/gen.h.proc $(foreach f,$(wildcard src/opt/answer.txt),$(if $(realpath $(f)),$(f),))' Makefile

# The directory it would arrive in is watched, deliberately.  The
# wildcard above is what hears a file the script named by hand, so the
# watch is not for that; it is for the script that globs a directory
# and prints what it found one optional line at a time, whose answer
# changes when a sibling shows up.  A directory that is not there
# expands to nothing, so it costs this build nothing at all.
grep -q '^obj/proc/gen.h.d:.*\$(wildcard src/opt)' Makefile

# And the build settles.  A missing prerequisite that make re-expands
# every run is a fine way to build forever, so this is worth asking.
timeout 60 make $MAKE_ARGS > settled.out 2>&1 || { cat settled.out; exit 1; }
cat settled.out
grep -q "Nothing to be done" settled.out

timeout 60 make $MAKE_ARGS > settled-again.out 2>&1 || { cat settled-again.out; exit 1; }
cat settled-again.out
grep -q "Nothing to be done" settled-again.out

exit 0
