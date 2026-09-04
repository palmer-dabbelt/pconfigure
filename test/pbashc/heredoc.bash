#include "tempdir.bash"

##############################################################################
# A directive inside a heredoc                                               #
##############################################################################
# A heredoc's body is text the script writes out, not script.  A test
# that writes a C file with "cat >x.c <<EOF" puts an "#include" line
# against the first column without meaning anything by it, and pbashc
# used to read that line as its own: the include was expanded away and
# the C file came out without it, or -- once a missing include became
# fatal -- pbashc went looking for stdio.h and the build stopped.
#
# The way this was lived with was indenting the include by a space,
# which put it out of the first column and so out of pbashc's reach.
# That worked and it was load-bearing, which is a bad thing for a
# space to be.
#
# Written with printf rather than a heredoc on purpose.  pbashc
# compiles this test too, so a heredoc here would be testing the fix
# with the fix -- and a regression would then stop the test from
# building rather than from passing, which says much less about what
# broke.
printf 'cat >out.c <<EOF\n#include "does_not_exist.h"\nEOF\necho done\n' \
    > in.bash

$PTEST_BINARY -i in.bash -o out.bash
cat out.bash

grep -q '^#include "does_not_exist.h"$' out.bash
grep -q '^echo done$' out.bash

# And the script it compiled to writes the file it was written to
# write, which is the thing all of this is actually about.
./out.bash
grep -q '^#include "does_not_exist.h"$' out.c

##############################################################################
# The other spellings of a heredoc                                           #
##############################################################################
# Quoting the delimiter is how a script asks for a body the shell
# expands nothing in.  It says nothing about where the body ends, so
# it has to make no difference here either.
printf "cat >q.c <<'END'\n" > quoted.bash
printf '#include "does_not_exist.h"\nEND\n' >> quoted.bash

$PTEST_BINARY -i quoted.bash -o quoted.out.bash
cat quoted.out.bash
grep -q '^#include "does_not_exist.h"$' quoted.out.bash

# "<<-" lets the body be indented along with the code around it, which
# means the line that ends it is indented too.  Getting that wrong
# would leave the heredoc open and swallow the rest of the file.
printf 'cat >t.c <<-TAB\n\t#include "does_not_exist.h"\n\tTAB\n' > tab.bash
printf 'echo after\n' >> tab.bash

$PTEST_BINARY -i tab.bash -o tab.out.bash
cat tab.out.bash
grep -q '#include "does_not_exist.h"' tab.out.bash
grep -q '^echo after$' tab.out.bash

##############################################################################
# The rest of the directives too                                             #
##############################################################################
# The "#include" is the one that gets noticed, because it is the one
# that changes what comes out.  The "#if" family is the same mistake
# and a quieter one: an "#ifdef" nobody defined used to blank out the
# body underneath it, and a header's closing "#endif" with no "#ifdef"
# above it ended the whole program with nothing printed at all.
printf 'cat >guard.h <<EOF\n#ifndef GUARD_H\n#define GUARD_H\n' > guard.bash
printf 'int guard(void);\n#endif\nEOF\necho after\n' >> guard.bash

$PTEST_BINARY -i guard.bash -o guard.out.bash
cat guard.out.bash
grep -q '^#ifndef GUARD_H$' guard.out.bash
grep -q '^int guard(void);$' guard.out.bash
grep -q '^#endif$' guard.out.bash
grep -q '^echo after$' guard.out.bash

##############################################################################
# What is not a heredoc                                                      #
##############################################################################
# Reading a "<<" that isn't a redirection as one is the same bug the
# other way round: everything after it becomes a body, and the
# directives in it stop being directives.
echo 'echo included' > beside.bash

# A "<<<" is a here-string.  It carries its body on the line it is
# written on, so it never waits for one -- and its text must not be
# read as a delimiter, which is what happens if only the first of the
# three '<' gets stepped over.
printf 'echo x <<< "some text"\n#include "beside.bash"\n' > herestring.bash

$PTEST_BINARY -i herestring.bash -o herestring.out.bash
cat herestring.out.bash
grep -q '^echo included$' herestring.out.bash

# In arithmetic a "<<" is a shift.  There is nothing in the syntax that
# says which one it is, so what is used is that a shift has its left
# operand written against it and a redirection has a word boundary
# there.
printf 'v=$((1<<20))\n#include "beside.bash"\n' > shift.bash

$PTEST_BINARY -i shift.bash -o shift.out.bash
cat shift.out.bash
grep -q '^echo included$' shift.out.bash

# A "<<" inside a string is text.  This one matters more than it
# looks: writing one script out of another is most of what a heredoc
# gets used for, so a script that says "<<EOF" inside quotes is a
# perfectly ordinary thing to find.
printf "echo 'cat >c <<EOF'\n" > quotedshift.bash
printf '#include "beside.bash"\n' >> quotedshift.bash

$PTEST_BINARY -i quotedshift.bash -o quotedshift.out.bash
cat quotedshift.out.bash
grep -q '^echo included$' quotedshift.out.bash

##############################################################################
# A heredoc inside a heredoc's body                                          #
##############################################################################
# A body is text all the way through, so a "<<" written in one opens
# nothing.  A script generating a script is where this turns up, and
# the delimiter that never arrives is what gives it away: read as a
# heredoc of its own, the inner "<<NEVER" would still be open after the
# outer one ended and would eat everything after it.
printf 'cat >gen.bash <<OUTER\ncat >x <<NEVER\nOUTER\n' > nested.bash
printf '#include "beside.bash"\n' >> nested.bash

$PTEST_BINARY -i nested.bash -o nested.out.bash
cat nested.out.bash
grep -q '^cat >x <<NEVER$' nested.out.bash
grep -q '^echo included$' nested.out.bash

##############################################################################
# And afterwards                                                             #
##############################################################################
# The whole point of the above is that it stops at the end of the
# heredoc.  A fix that left every "#include" after the first heredoc
# alone would pass every check up to here and still be useless.
printf 'cat >x <<EOF\n#include "does_not_exist.h"\nEOF\n' > after.bash
printf '#include "beside.bash"\n' >> after.bash

$PTEST_BINARY -i after.bash -o after.out.bash
cat after.out.bash
grep -q '^#include "does_not_exist.h"$' after.out.bash
grep -q '^echo included$' after.out.bash

exit 0
