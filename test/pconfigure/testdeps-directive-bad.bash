#include "harness_start.bash"

# The "#pconfigure" lines a test isn't allowed to write.  A directive
# is read where the test's source is named, which is a long way from
# where make would eventually have an opinion about it -- so a line
# that doesn't say anything usable is refused here, pointing at the
# file and the line it was written on, rather than left to come out
# later as a rule nobody meant.
#
# Every directive below is written with "echo" rather than inside a
# heredoc.  A '#' in the first column of this file is a directive for
# this file, which is a test of pconfigure that pconfigure builds, and
# one written into a heredoc would be read on the way past.

# Rebuilt from scratch for each case, since the point of every one of
# them is that no Makefile comes out the far side.
setup() {
    rm -rf case
    mkdir -p case/src case/test/app

    cat >case/Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash

BINARIES  += app
SOURCES   += app.c
TESTSRC   += t.bash
EOF

    cat >case/src/app.c <<EOF
int main(void) { return 0; }
EOF

    # The directive lands on the third line, so that a message which
    # names some other line is a message that got the answer wrong
    # rather than one that happened to be right about a file with a
    # single line in it.
    echo true > case/test/app/t.bash
    echo "" >> case/test/app/t.bash
    echo "$1" >> case/test/app/t.bash
}

# The subshell is the assertion: "set -e" is on, so a command expected
# to fail has to be somewhere a failure isn't fatal.  It stopping
# before it wrote anything is part of what's being checked -- a
# half-configured tree is something the next command trips over.
refuses() {
    if (cd case && $PTEST_BINARY $PCONFIGURE_ARGS) > out 2>&1
    then
        exit 1
    fi
    cat out
    test ! -e case/Makefile

    # Every one of these points at the test, since that's the file
    # somebody has to go and edit.
    grep -q "test/app/t.bash:3" out
}

##############################################################################
# A directive with nothing after it                                          #
##############################################################################
# The line is a directive because of how it's written rather than
# because of what it says, so one that says nothing is still a
# directive -- and there's nothing to do with it but say so.
setup '#pconfigure'
refuses
grep -q "says nothing" out
grep -q "TESTDEPS += path" out

##############################################################################
# A word that isn't a command                                                #
##############################################################################
# The likeliest way to get here is a comment: "#pconfigure" against
# the first column is the whole of what makes a line a directive, so a
# note about pconfigure written without a space after the '#' is one.
# The message says as much, because "'reads' is not a command" is not
# on its own much help to somebody who was writing prose.
setup '#pconfigure reads this file'
refuses
grep -q "'reads' is not a command" out
grep -q "put a space after the" out

##############################################################################
# A command that isn't a TESTDEPS                                            #
##############################################################################
# A real command, written somewhere it can't mean what it says.  A
# PREFIX is about the project, and the only thing a directive can put
# it on is the one test whose source it was read from -- so it's
# refused, and pointed at the file where it would have meant
# something.
setup '#pconfigure PREFIX = /usr'
refuses
grep -q "PREFIX can't be written in a #pconfigure" out
grep -q "Configfile" out

# The same for a command that is about tests but still about all of
# them: a DEPTESTS names one test that has to run before another, and
# a directive has no way to say which two.
setup '#pconfigure DEPTESTS += other.bash'
refuses
grep -q "DEPTESTS can't be written in a #pconfigure" out

##############################################################################
# A TESTDEPS that isn't written as one                                       #
##############################################################################
# The operator left off, which is what a shell script's own habits
# produce: nothing else in a test file has spaces around an '='.
setup '#pconfigure TESTDEPS bin/tool'
refuses
grep -q "isn't a command" out
grep -q "TESTDEPS += path" out

setup '#pconfigure TESTDEPS+=bin/tool'
refuses
grep -q "not a command" out

##############################################################################
# A TESTDEPS that reaches out of the project                                 #
##############################################################################
# Written in a test rather than in a Configfile, and refused for
# exactly the same reason -- the rule is about the path, not about
# where the path was written down.  What's worth pinning here is where
# the complaint points: at the test, which is the file that has to
# change.
setup '#pconfigure TESTDEPS += ../../nowhere/tool'
refuses
grep -q "TESTDEPS can't reach outside the project" out

exit 0
