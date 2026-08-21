#include "tempdir.bash"

##############################################################################
# An include that can't be found                                             #
##############################################################################
# This used to be silent, and silent was the worst thing it could be.
# An "#include" line is a directive rather than text, so it is never
# written to the output -- which meant a file whose include couldn't
# be found came out as that file with the include simply not in it,
# and pbashc said nothing and exited zero.
#
# For bash that produces a script which runs perfectly well and does
# the wrong thing.  The way it was actually found: a test taken out of
# the directory its harness lives in was compiled without the harness,
# so it never got the "set -e" or the "cd" into a temporary directory,
# and it ran its whole body wherever it happened to be standing.
# Written with printf rather than a heredoc, and that is not a style
# choice: pbashc compiles this test too, and it only treats a line as
# a directive when the "#include" starts at column zero.  A heredoc
# would put one there and pbashc would go looking for
# does_not_exist.bash while building the test that exists to prove it
# can't find it.  The other tests in the tree dodge the same thing by
# indenting the "#include <stdio.h>" in their C heredocs by a space.
printf '#include "does_not_exist.bash"\necho hello\n' > t.bash

if $PTEST_BINARY -i t.bash -o out.bash > t.out 2>&1
then
    exit 1
fi
cat t.out

# The file and the line, because the file that couldn't be found is
# not the file with the mistake in it, and only one of those two is
# somewhere anybody can go and fix it.
grep -q "^t\.bash:1: can't find 'does_not_exist\.bash'" t.out

# And what to do about it, which is the half that a message saying
# only "no" leaves out.
grep -q "check the spelling, or add a '-I'" t.out

# Nothing was left behind.  The output is written as it goes, so at
# the point this gave up there was already a shebang on disk -- and a
# file with a fresh mtime is one make takes for a finished one and
# never builds again, which would turn a loud failure back into a
# quiet one on the very next run.
test ! -e out.bash

##############################################################################
# Where it looked                                                            #
##############################################################################
# Every directory that was searched, in the order it was searched,
# because "can't find it" and "wasn't told where to look" are
# different problems with the same symptom.
mkdir -p one two

if $PTEST_BINARY -i t.bash -o out.bash -Ione -Itwo > dirs.out 2>&1
then
    exit 1
fi
cat dirs.out

grep -q "looked in '\.'" dirs.out
grep -q "looked in 'one'" dirs.out
grep -q "looked in 'two'" dirs.out

# Each of them once.  A file's own directory is very often on the -I
# list as well, and naming it twice reads like two different places
# were tried and both came up empty.
mkdir -p dup
printf '#include "nope.bash"\n' > dup/in.bash
if $PTEST_BINARY -i dup/in.bash -o dup.out.bash -Idup > dup.out 2>&1
then
    exit 1
fi
cat dup.out
test "$(grep -c "looked in 'dup'" dup.out)" = "1"

##############################################################################
# The ones that do resolve                                                   #
##############################################################################
# The whole point of the above is to leave these alone, so they're
# worth pinning down next to it: a warning that also broke the working
# case would just be a different way of not working.
echo 'echo beside' > beside.bash
printf '#include "beside.bash"\necho hello\n' > near.bash

$PTEST_BINARY -i near.bash -o near.out.bash
cat near.out.bash
grep -q "^echo beside\$" near.out.bash
grep -q "^echo hello\$" near.out.bash

# The included file is deliberately not named after the file doing the
# including.  A name that matches resolves next to the input before
# any -I is consulted, so the file quietly includes itself and the -I
# is never exercised at all.
echo 'echo elsewhere' > one/far.bash
printf '#include "far.bash"\necho hello\n' > viadash.bash

$PTEST_BINARY -i viadash.bash -o far.out.bash -Ione
cat far.out.bash
grep -q "^echo elsewhere\$" far.out.bash
grep -q "^echo hello\$" far.out.bash

##############################################################################
# An include inside an include                                               #
##############################################################################
# The failure has to climb back out.  The output is written on the way
# down, so a nested failure that stopped where it happened would leave
# a half-expanded file behind and hand back success -- which is the
# same bug one level lower.
printf '#include "missing_inner.bash"\n' > one/outer.bash
printf '#include "outer.bash"\necho hello\n' > nest.bash

if $PTEST_BINARY -i nest.bash -o nest.out.bash -Ione > nest.out 2>&1
then
    exit 1
fi
cat nest.out

# Named against the file that actually contains the bad line, rather
# than against the one pbashc was pointed at.
grep -q "^one/outer\.bash:1: can't find 'missing_inner\.bash'" nest.out
test ! -e nest.out.bash

##############################################################################
# A last line with no newline after it                                       #
##############################################################################
# The name of an included file ends at its closing quote.  Finding it
# by counting two characters back from the end of the line works right
# up until the line is the last one in a file that doesn't end in a
# newline, and then it takes a character off the name and the file
# stops being findable -- which, before this, meant it silently
# vanished.
echo 'echo tail' > one/tail.bash
printf 'echo first\n#include "tail.bash"' > nonl.bash

$PTEST_BINARY -i nonl.bash -o nonl.out.bash -Ione
cat nonl.out.bash
grep -q "^echo first\$" nonl.out.bash
grep -q "^echo tail\$" nonl.out.bash

exit 0
