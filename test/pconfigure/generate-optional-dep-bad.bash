#include "harness_start.bash"

# The one new way a "--deps" answer can be written wrong now that a
# leading '?' means something: a '?' with no path after it.  It has to
# be refused rather than interpreted, because both of the things
# pconfigure could do with it name something other than the input the
# script asked to watch, and neither says so.  From the top of a tree
# the line records a filter over "$(wildcard )", which expands to
# nothing, so an input the script believes it declared is thrown away
# and nothing watches it -- the exact bug the '?' was added to end,
# arriving by a new route.  From a subproject it records
# "$(wildcard sub/)", which is the project's own directory rather than
# any file the script named.
#
# An earlier draft of this comment claimed the subproject spelling was
# the worse of the two, because the output would then hang off a
# directory whose mtime moves whenever anything in the tree does and so
# would regenerate FOREVER.  That was measured and is false: a file
# created two levels down (sub/src/marker) moves sub/'s mtime not at all
# and triggers no regeneration, and a direct child (sub/marker)
# regenerates exactly once and then settles -- GEN counts of 1, 0, 0
# over three successive makes.  A directory's mtime answers for its
# direct children and nothing deeper, and the result is a stale output
# with the odd spurious rebuild, not a loop.  The argument for refusing
# is therefore the silent-drop one, which does reproduce.
#
# A script is in no position to be guessed at here: it printed the line,
# so it can be told about it, and the message has to name the script and
# say what to write instead -- including that printing nothing at all is
# the right answer for a script with no input to declare, since "say
# nothing" was the habit that caused the original incident and a reader
# of this message should not have to infer that it is allowed.
#
# Two shapes, because the guard used to test the LINE's length rather
# than the PATH's and so let "? " through to produce the empty wildcard
# it was written to refuse.  The configure-time answer is what this test
# reads; generate-optional-dep-bad-fragment.bash reads the one the build
# gets, which is the path that matters, because a .proc script edited to
# print this triggers the .d rule rather than a reconfigure.

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
--deps)     echo "?" ;;
--generate) echo "#define ANSWER 1" ;;
esac
EOF
chmod +x src/gen.h.proc

cat >src/app.c <<'EOF'
  #include "gen.h"
  #include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

# The subshell is the assertion: "set -e" is on, so a command expected
# to fail has to be somewhere a failure is not fatal.
if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    cat out
    exit 1
fi
cat out

# It says which script said it, what the '?' means, what to write
# instead, and that printing nothing is a legitimate answer.
grep -q "src/gen.h.proc --deps' printed a '?' with no path after it" out
grep -q "optional input" out
grep -q "?src/thing" out
grep -q "nothing at all" out

# And it points at the line of the Configfile that pulled the script in,
# which is where a reader of this message has to go to find out what
# asked for the generated file in the first place.
grep -q "Configfile:3" out

# Nothing was written: a half-configured tree is something the next
# command trips over rather than something anybody reads an error out
# of.
test ! -e Makefile

##############################################################################
# And a '?' followed by whitespace, which is the same thing              #
##############################################################################
# The guard this replaces asked whether the LINE was one character long,
# so this spelling sailed straight through it and recorded
# "$(wildcard  )" -- which expands to nothing, so the declared input was
# dropped exactly as the bare '?' would have dropped it, by a route that
# looked like it had been checked.  The '?' marks the line, so what
# follows it is a path and whitespace is not part of one: the path is
# empty either way and both are refused the same.
cat >src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     printf '? \n' ;;
--generate) echo "#define ANSWER 1" ;;
esac
EOF
chmod +x src/gen.h.proc

if $PTEST_BINARY $PCONFIGURE_ARGS > space.out 2>&1
then
    cat space.out
    exit 1
fi
cat space.out

grep -q "src/gen.h.proc --deps' printed a '?' with no path after it" space.out
test ! -e Makefile

exit 0
