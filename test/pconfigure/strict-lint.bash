#include "harness_start.bash"

# Every section below is its own little project in its own directory,
# because most of what's being checked here is the absence of a
# warning, and a warning that came from somewhere else is
# indistinguishable from the one that was expected.  One Configfile
# per question is what keeps the counts below honest.
top="$tempdir"

##############################################################################
# ENTITLEMENTS that landed somewhere nothing ever gets signed                #
##############################################################################
# Only a whole linked thing wears a signature, so an ENTITLEMENTS that
# came to rest on a source file, a header or a test is asking for
# something nobody will ever read.  That's worth being loud about
# rather than quiet: what comes out is a binary that starts up fine
# and then fails at the moment it reaches the one operation the
# entitlement was there to allow, which is a long way from the line
# that caused it.
mkdir -p $top/ent/src $top/ent/test/app
cd $top/ent

cat >Configfile <<EOF
ENTITLEMENTS  = top.plist

LANGUAGES    += c

BINARIES     += app
ENTITLEMENTS  = app.plist
SOURCES      += app.c
ENTITLEMENTS  = app.plist
TESTS        += t.c
ENTITLEMENTS  = app.plist

HEADERS      += foo.h
ENTITLEMENTS  = app.plist

GENERATE     += gen.c
ENTITLEMENTS  = app.plist
EOF

cat >src/app.c <<EOF
int main(void) { return 0; }
EOF

cat >src/foo.h <<EOF
int foo(void);
EOF

cat >test/app/t.c <<EOF
int main(void) { return 0; }
EOF

cat >src/gen.c.proc <<'EOF'
#!/bin/bash
echo "int gen(void) { return 0; }"
EOF
chmod +x src/gen.c.proc

$PTEST_BINARY $PCONFIGURE_ARGS > ent.out 2>&1
cat ent.out

# Four of those six lines are wrong and two of them are right, and the
# count is the assertion that says so.  The ENTITLEMENTS written
# directly under the BINARIES is the whole point of the command, and
# the one written at the top of the project before any target at all
# is inherited by every binary in it -- which is a thing somebody
# means rather than a thing somebody typed by accident.
test "$(grep -c 'warning: ENTITLEMENTS written under' ent.out)" = "4"

# The message names the context the line actually landed on, since
# "this is under the wrong thing" is only useful when it says which
# thing.  A GENERATE reports SOURCE because a GENERATE pushes a source
# context on top of the target it just opened -- the file it's about
# to write -- so an ENTITLEMENTS below one lands a level lower than it
# looks.  That's why SOURCE is expected twice here.
grep -q 'ENTITLEMENTS written under a HEADER' ent.out
grep -q 'ENTITLEMENTS written under a TEST' ent.out
test "$(grep -c 'ENTITLEMENTS written under a SOURCE' ent.out)" = "2"

# A warning leaves the build alone: the Makefile was written and the
# exit status was zero, which is the entire difference between this
# and what a STRICT asks for.
test -e Makefile

##############################################################################
# SOURCES with nothing open above it                                         #
##############################################################################
# A source file has to be compiled into something, and the something
# is whatever target is open above it.  With nothing open, the file is
# read, remembered and then dropped, so the warning is the only sign
# that anything happened at all.
mkdir -p $top/orphan/src
cd $top/orphan

cat >Configfile <<EOF
LANGUAGES += c

SOURCES   += orphan.c
EOF

cat >src/orphan.c <<EOF
int orphan(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS > orphan.out 2>&1
cat orphan.out
grep -q 'SOURCES with no target open above it is dropped' orphan.out

# The drop is the part worth pinning down, since the warning would be
# just as easy to write for something that did get built.  Nothing in
# the Makefile mentions the file at all: no object, no rule, not even
# something to clean.
cat Makefile
if grep -q 'orphan.c' Makefile
then
    exit 1
fi

# The check is about what's open, not about which file the line was
# read out of.  A CONFIG splits a project across several files and a
# target opened in one of them is still open in the next, which is how
# test/pconfigure/config.bash is written -- a check that looked at the
# Configfile rather than at the context stack would break it.
mkdir -p $top/split/src $top/split/Configfiles
cd $top/split

cat >Configfile <<EOF
LANGUAGES += c

CONFIG    += app
EOF

cat >Configfiles/app <<EOF
BINARIES  += app
EOF

cat >Configfile.app <<EOF
SOURCES   += app.c
EOF

cat >src/app.c <<EOF
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS > split.out 2>&1
cat split.out
test ! -s split.out
grep -q 'obj/src/app.c' Makefile

##############################################################################
# A space in a value that names a path                                       #
##############################################################################
# Everything after the operator is one value, so a line with a space
# in it names a single file whose name has a space in it.  Make does
# not agree: the rule that comes out of it gets split back up on
# whitespace into targets nobody asked for, and the build then fails
# somewhere with nothing to do with the line that caused it.
mkdir -p $top/space/src
cd $top/space
mkdir -p "$top/space/sub one/src"

cat >Configfile <<EOF
LANGUAGES   += c

SUBPROJECTS += sub one

SRCDIR       = src other
BINARIES    += app one
TESTDEPS    += bin/a bin/b
SOURCES     += app.c two.c
EOF

cat >"sub one/Configfile" <<EOF
LANGUAGES += c

BINARIES  += subapp
SOURCES   += subapp.c
EOF

cat >src/app.c <<EOF
int main(void) { return 0; }
EOF

cat >"sub one/src/subapp.c" <<EOF
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS > space.out 2>&1
cat space.out

# One warning per line that names a path, and the message names the
# command the line was written as, so that "write one of these per
# file" points at something the reader can go and find.
test "$(grep -c 'names a single file with a space in its name' space.out)" = "5"
grep -q 'write one SUBPROJECTS line per file' space.out
grep -q 'write one SRCDIR line per file' space.out
grep -q 'write one BINARIES line per file' space.out
grep -q 'write one TESTDEPS line per file' space.out
grep -q 'write one SOURCES line per file' space.out

# The other half of the check, and the reason it can't simply look at
# every line: a COMPILEOPTS is a command line, and a command line with
# no spaces in it is a command line with one argument in it.
# Complaining about these would make the warning useless to everybody
# who has ever written a compiler flag.
mkdir -p $top/cmdline/src
cd $top/cmdline

cat >Configfile <<EOF
BUILD_SYSTEMS += kconfig
CONFIGUREOPTS += --make-var A=b c

LANGUAGES     += c

BINARIES      += app
COMPILER       = cc -std=c99
COMPILEOPTS   += -g -O2
LINKOPTS      += -L. -lm
SOURCES       += app.c
EOF

cat >src/app.c <<EOF
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS > cmdline.out 2>&1
cat cmdline.out
test ! -s cmdline.out

# TESTSRC is two commands wearing one hat: it's processed as a TESTS
# and then again as a SOURCES, so a check written one level lower down
# would say the same thing three times about a line somebody wrote
# once.  That count is the whole reason the check sits where it does,
# above the split rather than below it, so it gets asserted rather
# than assumed.
mkdir -p $top/testsrc/src $top/testsrc/test/app
cd $top/testsrc

cat >Configfile <<EOF
LANGUAGES += c

BINARIES  += app
SOURCES   += app.c
TESTSRC   += t.c a.c
EOF

cat >src/app.c <<EOF
int main(void) { return 0; }
EOF

cat >test/app/t.c <<EOF
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS > testsrc.out 2>&1
cat testsrc.out
test "$(grep -c 'names a single file with a space in its name' testsrc.out)" = "1"
grep -q 'write one TESTSRC line per file' testsrc.out

##############################################################################
# COMPAT                                                                     #
##############################################################################
# COMPAT was going to say which pconfigure a project was written
# against, and never became anything: it has been parsed and thrown
# away since the day it was added.  So there's nothing here to be
# careful about -- whatever it was set to, and whichever operator it
# was set with, the answer is the same one, and it points at STRICT,
# which is what the line was reaching for.
mkdir -p $top/compat/src
cd $top/compat

cat >Configfile <<EOF
COMPAT     = 1.0
COMPAT    += 0.9
COMPAT     = banana

LANGUAGES += c

BINARIES  += app
SOURCES   += app.c
EOF

cat >src/app.c <<EOF
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS > compat.out 2>&1
cat compat.out
test "$(grep -c 'COMPAT is read and then thrown away' compat.out)" = "3"
grep -q 'wants STRICT' compat.out

##############################################################################
# VERBOSE and DEBUG, which ignore what they're set to                        #
##############################################################################
# Writing either of these turns the thing on, and "= false" turns it
# on exactly as surely as "= true" does.  A Configfile that says the
# opposite of what the build does is worth a word, so anything that
# isn't the one spelling that means what it reads as gets one --
# including a "+=", since an operator that looks like it adds to a
# list is another way of believing this line has a value.
mkdir -p $top/bools/src
cd $top/bools

cat >Configfile <<EOF
VERBOSE  = false
VERBOSE  = true
VERBOSE += true
DEBUG    = false
DEBUG    = true
DEBUG   += true

LANGUAGES += c

BINARIES  += app
SOURCES   += app.c
EOF

cat >src/app.c <<EOF
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS > bools.out 2>&1
cat bools.out

# Two apiece: the "= false" and the "+= true", and not the "= true"
# sitting between them.
test "$(grep -c "VERBOSE ignores what it's set to" bools.out)" = "2"
test "$(grep -c "DEBUG ignores what it's set to" bools.out)" = "2"

# And then the compatibility contract, which is the whole reason this
# is a warning rather than a fix.  A project with "VERBOSE = false" in
# it gets a verbose build today and has to keep getting one tomorrow:
# the warning says the line means the opposite of what it reads as,
# and then goes on meaning it.  Recipe lines that aren't prefixed with
# an '@' are what a verbose build looks like.
mkdir -p $top/verbose/src $top/quiet/src
cd $top/verbose

cat >Configfile <<EOF
VERBOSE    = false

LANGUAGES += c

BINARIES  += app
SOURCES   += app.c
EOF

cat >src/app.c <<EOF
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS > verbose.out 2>&1
cat verbose.out
grep -q "VERBOSE ignores what it's set to" verbose.out

cat Makefile
if grep -q '^	@' Makefile
then
    exit 1
fi

# The same project without the line, which is the control: without it
# every recipe line is hidden, so the absence of '@' up there really
# is the VERBOSE talking rather than a Makefile that never had any.
cd $top/quiet

cat >Configfile <<EOF
LANGUAGES += c

BINARIES  += app
SOURCES   += app.c
EOF

cat >src/app.c <<EOF
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS > quiet.out 2>&1
cat quiet.out
test ! -s quiet.out
grep -q '^	@' Makefile

##############################################################################
# A second SRCPATH                                                           #
##############################################################################
# SRCPATH rewrites the source directories in place rather than
# replacing them, so a second one is read relative to whatever the
# first one already produced.  It's written with an '=', which reads
# as a promise that it replaces, and it doesn't.
mkdir -p $top/srcpath/b/a/src
cd $top/srcpath

cat >Configfile <<EOF
SRCPATH    = a
SRCPATH    = b

LANGUAGES += c

BINARIES  += app
SOURCES   += app.c
EOF

cat >b/a/src/app.c <<EOF
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS > srcpath.out 2>&1
cat srcpath.out
test "$(grep -c "a second SRCPATH doesn't replace the first one" srcpath.out)" = "1"

# A warning is only worth anything if it describes what really
# happens, so the stacking gets asserted too: "a" and then "b" looks
# under "b/a", which is where this project's one source file was put.
cat Makefile
grep -q 'b/a/src/app.c' Makefile

# One of them is the ordinary way to write it and says nothing.
mkdir -p $top/onepath/a/src
cd $top/onepath

cat >Configfile <<EOF
SRCPATH    = a

LANGUAGES += c

BINARIES  += app
SOURCES   += app.c
EOF

cat >a/src/app.c <<EOF
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS > onepath.out 2>&1
cat onepath.out
test ! -s onepath.out

##############################################################################
# A target that never got any sources                                        #
##############################################################################
# A SRCDIR goes back to the top of the project, which closes whatever
# target was open above it without opening a new one.  So this reads
# like a binary built out of one source file and is in fact a binary
# with nothing in it and a source file attached to nothing, and both
# ends of that get said: the source is dropped where it's written, and
# the target is found empty later on, when the Makefile is written.
mkdir -p $top/empty/src
cd $top/empty

cat >Configfile <<EOF
LANGUAGES += c

BINARIES  += app
SRCDIR     = src
SOURCES   += app.c
EOF

cat >src/app.c <<EOF
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS > empty.out 2>&1
cat empty.out
grep -q 'SOURCES with no target open above it is dropped' empty.out
grep -q "'app' has nothing to build: no SOURCES ever landed on it" empty.out

# The same three lines with the SRCDIR moved above the BINARIES, which
# is where somebody who wanted this meant to put it.  Nothing to say.
mkdir -p $top/notempty/src
cd $top/notempty

cat >Configfile <<EOF
LANGUAGES += c

SRCDIR     = src
BINARIES  += app
SOURCES   += app.c
EOF

cat >src/app.c <<EOF
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS > notempty.out 2>&1
cat notempty.out
test ! -s notempty.out

##############################################################################
# Two targets that come out in the same place                                #
##############################################################################
# Two targets with the same output path are one target: the second
# one's rules are identical to the first's, so they fold together and
# everything written underneath the second goes nowhere -- which looks
# exactly like it worked.
mkdir -p $top/dup/src
cd $top/dup

cat >Configfile <<EOF
LANGUAGES += c

BINARIES  += app
SOURCES   += app.c

BINARIES  += app
SOURCES   += app.c
EOF

cat >src/app.c <<EOF
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS > dup.out 2>&1
cat dup.out
grep -q "'bin/app' was already asked for on" dup.out

# The comparison is on where a target comes out and not on what it's
# called, which is the half that would break something real: two
# libraries with the same name under different LIBDIRs are two
# libraries in two places, and test/pconfigure/libdir.bash is built
# out of exactly that.  A check written against the name would call
# them a duplicate and stop a test that has always passed.
mkdir -p $top/libdir/src
cd $top/libdir

cat >Configfile <<EOF
LANGUAGES += c

LIBDIR     = lib1
LIBRARIES += liba.so
SOURCES   += a.c

LIBDIR     = lib2
LIBRARIES += liba.so
SOURCES   += a.c
EOF

cat >src/a.c <<EOF
int a(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS > libdir.out 2>&1
cat libdir.out
test ! -s libdir.out
grep -q 'lib1/liba.so' Makefile
grep -q 'lib2/liba.so' Makefile

##############################################################################
# TESTS with nothing open above it, which is an error and not a warning      #
##############################################################################
# A test belongs to the thing it exercises, and with nothing open the
# context it hangs off is the project's own, which has no command
# behind it.  What used to happen was a null dereference: a signal, no
# message, and no hint about which line did it.  There's no behaviour
# there to stay compatible with, so this is an error in every mode
# rather than a warning STRICT promotes -- nobody can be relying on a
# crash.
mkdir -p $top/notest/test
cd $top/notest

cat >Configfile <<EOF
LANGUAGES += c

TESTS     += t.c
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS > tests.out 2>&1
then
    exit 1
fi
cat tests.out
grep -q "error: TESTS with no target open above it has nothing to test" tests.out

# The line it names is the line as it was written.  A TESTSRC is
# rewritten into a TESTS on the way in, so the message says TESTS
# while the line it quotes still says TESTSRC, which is what somebody
# has to go and find in their Configfile.
cat >Configfile <<EOF
LANGUAGES += c

TESTSRC   += t.c
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS > testsrc-err.out 2>&1
then
    exit 1
fi
cat testsrc-err.out
grep -q "error: TESTS with no target open above it has nothing to test" testsrc-err.out
grep -q "'TESTSRC += t.c'" testsrc-err.out

# It stops rather than writing a Makefile, and it stops without a
# STRICT anywhere in sight: the default strictness promotes nothing,
# so a project that never asked for any of this is still told about
# this one.
test ! -e Makefile
if grep -q 'STRICT' tests.out
then
    exit 1
fi

exit 0
