#include "tempdir.bash"

##############################################################################
# A rebuild replaces the program                                             #
##############################################################################
# The output of a compile is a program, and a program is a thing
# something may well be running.  Opening it and writing through it
# does not replace it: it changes the file that is already open, so
# whatever had it mapped is running against contents that have moved
# underneath.
#
# On macOS that is fatal rather than merely rude.  The kernel checks a
# program's code signature once and remembers the answer against that
# file, so a file whose contents changed while the answer stayed
# behind is one the next exec of kills with SIGKILL, printing nothing
# at all about which file or why.
printf 'echo one\n' > t.bash
$PTEST_BINARY -i t.bash -o out.bash

test -x out.bash
test "$(./out.bash)" = "one"

inode() {
    ls -i "$1" | awk '{print $1}'
}

was="$(inode out.bash)"

printf 'echo two\n' > t.bash
$PTEST_BINARY -i t.bash -o out.bash

# A different file, not the same file with different contents in it.
test "$(inode out.bash)" != "$was"
test "$(./out.bash)" = "two"

worked="$(inode out.bash)"

# It arrives runnable rather than being made runnable once it's there,
# so there is no moment where the program exists and can't be run.
test -x out.bash

# ... and the name it was written under is not left lying about.
test ! -e out.bash.tmp

##############################################################################
# A compile that fails                                                       #
##############################################################################
# Written with printf rather than a heredoc, and that is not a style
# choice: pbashc compiles this test too, and it only treats a line as
# a directive when the "#include" starts at column zero.
printf '#include "does_not_exist.bash"\necho three\n' > t.bash

if $PTEST_BINARY -i t.bash -o out.bash > fail.out 2>&1
then
    exit 1
fi
cat fail.out

# The program that was there is still there, and is still the one that
# worked.  The output is written as it goes, so a compile that gives
# up part way has written a shebang and however far it got -- landing
# that on the finished program would replace something that runs with
# something that doesn't, on the strength of a compile that failed.
test "$(./out.bash)" = "two"

# Untouched, rather than rebuilt into something that happens to be the
# same: the compile that failed never opened it.
test "$(inode out.bash)" = "$worked"

# And nothing is left behind under either name.  A half-written file
# with a fresh mtime is one make takes for a finished one and never
# builds again, which turns a loud failure into a quiet one on the
# very next run.
test ! -e out.bash.tmp

exit 0
