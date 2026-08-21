#include "harness_start.bash"

##############################################################################
# The default                                                                #
##############################################################################
# A project that says nothing about STRICT gets exactly what it got
# before any of this existed: the line is accepted, the Makefile is
# written, and the only thing that changed is a paragraph on stderr.
# That is the whole reason ten of these could be added at once --
# none of them is allowed to stop a tree that built yesterday.
#
# COMPAT is the warning this file is built around, because it is the
# one that needs nothing else to be true to trigger: no target, no
# context, no second line.  What's being tested here is the knob
# rather than anything the knob reaches, so the simplest warning there
# is makes the best probe.
mkdir -p default/src
echo 'int main(void) { return 0; }' > default/src/app.c

cat >default/Configfile <<EOF
LANGUAGES += c

COMPAT    = 1.0

BINARIES  += app
SOURCES   += app.c
EOF

(cd default && $PTEST_BINARY $PCONFIGURE_ARGS) > default.out 2>&1
cat default.out

# A Makefile that builds the thing that was asked for, rather than a
# file left half-written on the way out.
test -e default/Makefile
grep -q "^bin/app:" default/Makefile

# The shape of the message, line by line, because each line is there
# for a different reason.  The locator is a filename, a line number
# and the text of the line itself: somebody who trips one of these has
# an editor open and wants to get to the line rather than guess which
# of four COMPATs it was.
grep -q "^\./Configfile:3 'COMPAT = 1.0'\$" default.out

# Then what is wrong, tagged "warning" -- which is the word that says
# the build carried on -- and then what to do instead, since "no" on
# its own is not much help to somebody who wrote the line for a
# reason.
grep -q "^  warning: COMPAT is read and then thrown away" default.out
grep -q "^  delete the line;" default.out

# And last the version to write down, which is a property of the
# warning rather than of the project reading it: somebody being told
# about something wants the number that turns it into an error, and
# that number is the release the warning was added in.
grep -q "^  ('STRICT = v0.13' makes this an error)\$" default.out

# Nothing in any of that said "error", which is worth an assertion of
# its own: that word is the only thing telling the two modes apart to
# anybody reading a build log, so it has to mean what it says.
if grep -q "error:" default.out
then
    exit 1
fi

##############################################################################
# Promotion                                                                  #
##############################################################################
# The opt-in, written where a project says everything else about
# itself.  It goes at the top of the Configfile because it has to be
# read before the line it is meant to catch.
mkdir -p promote/src
echo 'int main(void) { return 0; }' > promote/src/app.c

cat >promote/Configfile <<EOF
STRICT    = v0.13

LANGUAGES += c

COMPAT    = 1.0

BINARIES  += app
SOURCES   += app.c
EOF

status=0
(cd promote && $PTEST_BINARY $PCONFIGURE_ARGS) > promote.out 2>&1 || status=$?
cat promote.out

# It stopped, and it stopped by abort() rather than by returning some
# tidy failure code -- 128 plus SIGABRT.  The number itself isn't the
# interesting part; that the process died on the line it was
# complaining about is, since that is what makes it impossible for
# anything further to have been written.
test "$status" -eq 134

# The same complaint, word for word, with one word changed.  A project
# that promotes a warning and then gets a differently-worded message
# has to learn the same diagnostic twice.
grep -q "^\./Configfile:5 'COMPAT = 1.0'\$" promote.out
grep -q "^  error: COMPAT is read and then thrown away" promote.out

# The trailing line is the other half of that pair: in warning mode it
# names the version that would promote this, and in error mode it
# names the version that did.  Somebody whose build has just started
# failing needs to be pointed at the line they wrote, not at a line
# they might write.
grep -q "^  ('STRICT = v0.13' is what makes this an error)\$" promote.out

# Nothing was written, which is the assertion that matters most in
# this file.  A run that complains and then leaves a Makefile behind
# has produced a tree where the next command works and quietly builds
# whatever the bad line meant, and getting out of exactly that
# situation is what STRICT is for.
test ! -e promote/Makefile

##############################################################################
# The command line                                                           #
##############################################################################
# The same knob from outside the project, for a tree somebody else
# wrote and for a build that wants to be told about every project it
# configures without editing any of them.  This Configfile says
# nothing about STRICT at all, so everything below it comes from the
# flag.
mkdir -p cmdline/src
echo 'int main(void) { return 0; }' > cmdline/src/app.c

cat >cmdline/Configfile <<EOF
LANGUAGES += c

COMPAT    = 1.0

BINARIES  += app
SOURCES   += app.c
EOF

if (cd cmdline && $PTEST_BINARY $PCONFIGURE_ARGS --strict v0.13) > cmdline.out 2>&1
then
    exit 1
fi
cat cmdline.out

grep -q "^  error: COMPAT is read and then thrown away" cmdline.out
grep -q "^  ('STRICT = v0.13' is what makes this an error)\$" cmdline.out
test ! -e cmdline/Makefile

##############################################################################
# Spellings                                                                  #
##############################################################################
# One version, three ways of writing it.  The 'v' is how the releases
# are named and how anybody copying a number out of a tag will write
# it; leaving it off is how the same number is written everywhere
# else; and a component left off is that component set to zero, which
# is already what "v0.13" means to everybody who says it out loud.
# All three have to land on the same version, because a project that
# picked the spelling that didn't work would have every warning
# underneath it silently turned back off.
mkdir -p spell/src
echo 'int main(void) { return 0; }' > spell/src/app.c

for version in v0.13 0.13 v0.13.0
do
    rm -f spell/Makefile

    cat >spell/Configfile <<EOF
STRICT    = $version

LANGUAGES += c

COMPAT    = 1.0

BINARIES  += app
SOURCES   += app.c
EOF

    if (cd spell && $PTEST_BINARY $PCONFIGURE_ARGS) > spell.out 2>&1
    then
        exit 1
    fi
    cat spell.out

    grep -q "^  error: COMPAT is read and then thrown away" spell.out
    test ! -e spell/Makefile

    # And the version reads back the way the release is named,
    # whichever of the three went in.  That is a stronger statement
    # than "all three promoted": it says the three spellings became
    # one version, rather than three versions that each happen to be
    # at least v0.13.
    grep -q "^  ('STRICT = v0.13' is what makes this an error)\$" spell.out
done

# A version in between two releases is understood and is still older
# than the one that promotes, so it promotes nothing.  This is the
# half a parser that only read two components would get wrong, and it
# would get it wrong in the direction that turns warnings off.
rm -f spell/Makefile

cat >spell/Configfile <<EOF
STRICT    = v0.12.1

LANGUAGES += c

COMPAT    = 1.0

BINARIES  += app
SOURCES   += app.c
EOF

(cd spell && $PTEST_BINARY $PCONFIGURE_ARGS) > patch.out 2>&1
cat patch.out
grep -q "^  warning: COMPAT is read and then thrown away" patch.out
test -e spell/Makefile

##############################################################################
# Clamping                                                                   #
##############################################################################
# There has never been a pconfigure that did any of this differently,
# so every version older than v0.12 describes the same behaviour and
# they all mean the floor.  A project pinned back to something ancient
# is asking for the oldest behaviour there is and gets it, rather than
# getting a comparison against a release that never existed.
mkdir -p clamp/src
echo 'int main(void) { return 0; }' > clamp/src/app.c

for version in v0.9.3 v0.11
do
    rm -f clamp/Makefile

    cat >clamp/Configfile <<EOF
STRICT    = $version

LANGUAGES += c

COMPAT    = 1.0

BINARIES  += app
SOURCES   += app.c
EOF

    (cd clamp && $PTEST_BINARY $PCONFIGURE_ARGS) > clamp.out 2>&1
    cat clamp.out

    grep -q "^  warning: COMPAT is read and then thrown away" clamp.out
    test -e clamp/Makefile

    # Clamped up to the floor rather than thrown out: the line was
    # accepted and the warning still printed, so a project pinned
    # backwards is still being told about the things it is relying on.
    grep -q "^  ('STRICT = v0.13' makes this an error)\$" clamp.out
done

##############################################################################
# The future                                                                 #
##############################################################################
# A version newer than any of these warnings promotes all of them,
# which is the property that makes this a knob rather than a list.  A
# project pinned forward is saying "tell me about everything", and it
# goes on meaning that as warnings get added after it was written --
# nobody has to come back and edit the number to keep getting what
# they asked for.
mkdir -p future/src
echo 'int main(void) { return 0; }' > future/src/app.c

cat >future/Configfile <<EOF
STRICT    = v1.0

LANGUAGES += c

COMPAT    = 1.0

BINARIES  += app
SOURCES   += app.c
EOF

if (cd future && $PTEST_BINARY $PCONFIGURE_ARGS) > future.out 2>&1
then
    exit 1
fi
cat future.out

grep -q "^  error: COMPAT is read and then thrown away" future.out
test ! -e future/Makefile

# The version echoed back is the one the project asked for rather than
# the one the warning was added in, since the question that line
# answers is "why did this fail", and the answer is a line somebody
# wrote.
grep -q "^  ('STRICT = v1.0' is what makes this an error)\$" future.out

##############################################################################
# Garbage                                                                    #
##############################################################################
# Something that isn't a version at all is a hard error in both modes,
# and this is the one place in the whole feature where that is the
# right answer.  Everything else here is a warning because somebody
# out there is relying on it -- but nobody is relying on a misspelled
# STRICT, and a misspelled STRICT that got quietly ignored would turn
# every warning underneath it back off while looking exactly like a
# project that had asked to be told.  That is the single failure this
# is not allowed to have, so it refuses to guess.
#
# Four different ways of being wrong: a word that is not a number, a
# 'v' with nothing after it, one component too many, and a component
# that isn't there.
mkdir -p garbage/src
echo 'int main(void) { return 0; }' > garbage/src/app.c

for version in banana v v1.2.3.4 v1..2
do
    rm -f garbage/Makefile

    cat >garbage/Configfile <<EOF
STRICT    = $version

LANGUAGES += c

BINARIES  += app
SOURCES   += app.c
EOF

    if (cd garbage && $PTEST_BINARY $PCONFIGURE_ARGS) > garbage.out 2>&1
    then
        exit 1
    fi
    cat garbage.out

    # It names the line it couldn't read, the way every other
    # complaint in here does, and then says how the line is supposed
    # to look -- which for a version is more use than any amount of
    # detail about what was wrong with this one.
    grep -q "^\./Configfile:1 'STRICT = $version'\$" garbage.out
    grep -q "STRICT wants a pconfigure version" garbage.out
    grep -q "'STRICT = v0.13'" garbage.out

    test ! -e garbage/Makefile
done

##############################################################################
# Inheritance                                                                #
##############################################################################
# How loudly a build wants to be told about any of this is a property
# of the build rather than of one Configfile, so STRICT rides down
# into a SUBPROJECTS the way CROSS_COMPILE does.  A project that asked
# to be told about its own lines and then heard nothing about the
# lines in the tree it pulled in has been told half of what it asked
# for.
mkdir -p inherit/src inherit/sub/src
echo 'int main(void) { return 0; }' > inherit/src/top.c
echo 'int main(void) { return 0; }' > inherit/sub/src/app.c

cat >inherit/Configfile <<EOF
STRICT      = v0.13

SUBPROJECTS += sub

LANGUAGES   += c

BINARIES    += top
SOURCES     += top.c
EOF

cat >inherit/sub/Configfile <<EOF
LANGUAGES += c

COMPAT    = 2.0

BINARIES  += app
SOURCES   += app.c
EOF

if (cd inherit && $PTEST_BINARY $PCONFIGURE_ARGS) > inherit.out 2>&1
then
    exit 1
fi
cat inherit.out

# The complaint names the subproject's own file and the subproject's
# own line, because that is where the line is: the strictness
# travelled down, the diagnostic did not travel back up.
grep -q "^sub/Configfile:3 'COMPAT = 2.0'\$" inherit.out
grep -q "^  error: COMPAT is read and then thrown away" inherit.out

# And neither end of the build got written out.  A subproject that
# failed leaves the whole thing unconfigured, since a top-level
# Makefile that recurses into a directory with no Makefile in it is
# worse than no Makefile at all.
test ! -e inherit/Makefile
test ! -e inherit/sub/Makefile

##############################################################################
# Relaxing                                                                   #
##############################################################################
# The same tree, with the subproject writing a STRICT of its own.  A
# vendored tree, or one shared between projects that don't agree about
# this, gets to say how strict it is prepared to be, and it says it
# the only way it can say anything: in its own Configfile.  What it
# inherited was a default rather than an order.
mkdir -p relax/src relax/sub/src
echo 'int main(void) { return 0; }' > relax/src/top.c
echo 'int main(void) { return 0; }' > relax/sub/src/app.c

cat >relax/Configfile <<EOF
STRICT      = v0.13

SUBPROJECTS += sub

LANGUAGES   += c

BINARIES    += top
SOURCES     += top.c
EOF

cat >relax/sub/Configfile <<EOF
STRICT    = v0.12

LANGUAGES += c

COMPAT    = 2.0

BINARIES  += app
SOURCES   += app.c
EOF

(cd relax && $PTEST_BINARY $PCONFIGURE_ARGS) > relax.out 2>&1
cat relax.out

grep -q "^sub/Configfile:5 'COMPAT = 2.0'\$" relax.out
grep -q "^  warning: COMPAT is read and then thrown away" relax.out
test -e relax/Makefile
test -e relax/sub/Makefile

##############################################################################
# ... and the project that pulled it in is still strict                      #
##############################################################################
# The other half, and the half that a strictness kept somewhere global
# rather than on the context would get wrong: a subproject relaxing
# itself is a statement about the subproject.  The line that proves it
# has to be in the top-level Configfile, so it goes in a second run
# over the same tree -- the first run had to reach the subproject to
# say anything at all, and this one has to stop before it gets there.
rm -f relax/Makefile relax/sub/Makefile

cat >relax/Configfile <<EOF
STRICT      = v0.13

COMPAT      = 3.0

SUBPROJECTS += sub

LANGUAGES   += c

BINARIES    += top
SOURCES     += top.c
EOF

if (cd relax && $PTEST_BINARY $PCONFIGURE_ARGS) > strict-top.out 2>&1
then
    exit 1
fi
cat strict-top.out

grep -q "^\./Configfile:3 'COMPAT = 3.0'\$" strict-top.out
grep -q "^  error: COMPAT is read and then thrown away" strict-top.out
test ! -e relax/Makefile

exit 0
