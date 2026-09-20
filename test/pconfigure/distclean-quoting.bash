#include "harness_start.bash"

top="$tempdir"

##############################################################################
# Every path in a distclean is one word of shell                             #
##############################################################################
# "make distclean" is an "rm -rf" of every output directory of every
# project in the run, and two of the things in that list came out of a
# Configfile: the directory a LIBDIR named, and the directory a
# SUBPROJECTS named, which is what the object directory of a
# subproject hangs off.  Those are the two commands in this
# pconfigure that move an output directory -- HDRDIR is a name in the
# enum that aborts with "not implemented" when anybody writes it.
#
# Neither of those is a path this has to be right about in the way an
# install prefix would be -- they are output directories, which this
# build makes and this build removes.  What they are is text somebody
# wrote, and an "rm -rf" built by pasting text onto the end of a
# command is a command whose meaning that text gets a vote on.
#
# Two ways it goes wrong, and they are different ways: a space splits
# one directory into two arguments and the recipe runs perfectly
# happily against directories nobody named, while an apostrophe ends
# the quoting and the shell gives up on the line before running any of
# it.

##############################################################################
# A directory whose name has a space in it                                   #
##############################################################################
# "rm -rf my lib" is two arguments, and the one thing it certainly
# does not do is remove "my lib".  What it does instead is remove a
# "my" and a "lib" if there are any, which there are: "lib" is the
# default library directory, and a project that moved its LIBDIR still
# has whatever else was in the tree.
#
# So the assertion is on both halves -- the directory that was named
# goes, and the two directories that were not named stay.
#
# Nothing is built here, and that is not laziness: pconfigure warns
# about this line because the rules it makes are rules make splits
# back up into targets nobody meant, so the build is broken by the
# same character this is about.  A distclean is a standalone target
# and runs anyway, which is exactly the shape of the hazard -- the
# target somebody reaches for when a build has gone wrong is the one
# that reads this path.  So the output directory is made by hand,
# which is all make would have done with it.
mkdir -p $top/spaced/src $top/spaced/my $top/spaced/lib
mkdir -p "$top/spaced/my lib"
echo 'int spaced(void) { return 1; }' > $top/spaced/src/spaced.c
echo "output" > "$top/spaced/my lib/libspaced.so"
echo "not output" > $top/spaced/my/keep.txt
echo "not output" > $top/spaced/lib/keep.txt

# The warning is expected and is not what is under test: a LIBDIR
# whose value has a space in it is one path with a space in it, and
# pconfigure says so.  What is under test is what the recipe does with
# the answer once the line has been read.
cat >$top/spaced/Configfile <<'EOF'
LANGUAGES += c
LIBDIR = my lib

LIBRARIES += libspaced.so
SOURCES   += spaced.c
EOF
cat $top/spaced/Configfile

(cd $top/spaced && $PTEST_BINARY $PCONFIGURE_ARGS) > $top/spaced.out 2>&1
cat $top/spaced.out

sed -n '/^distclean:/,/^$/p' $top/spaced/Makefile > $top/spaced.rule
cat $top/spaced.rule

# One word, spelled the one way a shell reads a space as part of a
# name.  Written into a file and matched whole, since a pattern with
# this much quoting in it is a pattern the shell reading this test has
# an opinion about too.
cat >$top/spaced.want <<'EOF'
rm -rf 'my lib'
EOF
grep -q -F -f $top/spaced.want $top/spaced.rule

(cd $top/spaced && make $MAKE_ARGS distclean) > $top/spaced-clean.out 2>&1
cat $top/spaced-clean.out
test ! -e "$top/spaced/my lib"

# And the two directories the split would have taken are still there,
# which is the half that says this was a data-destruction bug rather
# than a tidiness one.
test -f $top/spaced/my/keep.txt
test -f $top/spaced/lib/keep.txt

##############################################################################
# A subproject whose directory has an apostrophe in it                       #
##############################################################################
# A subproject's object directory is its own directory with "obj" on
# the end, and the Makefile a parent includes is named after it too --
# so a checkout under a directory named after somebody puts an
# apostrophe into two lines of the parent's distclean.  Unquoted, the
# apostrophe opens a quote that never closes and the shell refuses the
# whole line: "make distclean" stops with "unexpected EOF while
# looking for matching" partway through, having removed whatever it
# got to first.
#
# Running it is the assertion.  A recipe that the shell would not read
# fails whatever else is wrong with it, so this needs the directories
# checked afterwards as well: a distclean that ran and removed nothing
# looks identical to one that worked, from "make" alone.
mkdir -p "$top/quoted/it's/src" $top/quoted/src
echo 'int quoted(void) { return 1; }' > "$top/quoted/it's/src/quoted.c"
echo 'int main(void) { return 0; }' > $top/quoted/src/main.c

cat >$top/quoted/Configfile <<'EOF'
LANGUAGES += c

SUBPROJECTS += it's

BINARIES  += main
SOURCES   += main.c
EOF

cat >"$top/quoted/it's/Configfile" <<'EOF'
LANGUAGES += c

LIBRARIES += libquoted.so
SOURCES   += quoted.c
EOF

(cd $top/quoted && $PTEST_BINARY $PCONFIGURE_ARGS)

sed -n '/^distclean:/,/^$/p' $top/quoted/Makefile > $top/quoted.rule
cat $top/quoted.rule

# Stop quoting, escape the apostrophe out in the open, start quoting
# again, which is the one way a single-quoted shell string can hold
# the one character it cannot hold.  Two lines carry it: the
# subproject's object directory, and the Makefile the parent wrote
# into it under a name built out of where the subproject sits.
cat >$top/quoted.want <<'EOF'
rm -rf 'it'\''s/obj'
EOF
cat $top/quoted.want
grep -q -F -f $top/quoted.want $top/quoted.rule

cat >$top/quoted-makefile.want <<'EOF'
rm -rf 'it'\''s/obj/Makefile.it'\''s'
EOF
grep -q -F -f $top/quoted-makefile.want $top/quoted.rule

# Nothing is built, for the same reason the project above isn't: a
# compile rule names the source it was made from, so an apostrophe in
# a subproject's directory is a hazard in the build rules as well --
# a different one, in a different place, and one that is answered by
# not being fixed.  A compile rule reaches a path through the make
# variable that stands for the project's directory, so quoting the
# recipe quotes nothing that is inside the expansion, and the variable
# cannot hold an escaped path because the same variable names make
# prerequisites.  That is written up where somebody hits it -- see the
# class comment on makefile::path_prefix and "Odd Behavior" in
# doc/pconfigure.tex -- and it is why this file stops at the recipes
# that can be quoted rather than pretending to cover the ones that
# can't.  What this is about is the target somebody reaches for when a
# build has gone wrong, so the output directories are made by hand,
# which is all a build would have done with them.
mkdir -p "$top/quoted/it's/obj" "$top/quoted/it's/lib" $top/quoted/obj
echo "output" > "$top/quoted/it's/obj/stale.o"
echo "output" > "$top/quoted/it's/lib/libquoted.so"
echo "output" > $top/quoted/obj/stale.o

# The status is caught rather than left to "set -e", which is what
# makes the two greps below reachable at all: a recipe the shell gives
# up on is a recipe make reports as failed, so letting the failure
# through here would end the test one line above the check that says
# what went wrong.  What is wanted from a failure is the sentence the
# shell printed, and that is read first.
status=0
(cd $top/quoted && make $MAKE_ARGS distclean) > $top/quoted-clean.out 2>&1 \
    || status=$?
cat $top/quoted-clean.out

# The shell read the whole recipe rather than giving up partway
# through it.  Named outright rather than left to the status, because
# "make failed" says nothing about which line it gave up on -- what
# happens is that make reports an error from a line whose text nobody
# is reading, and the directories the lines after it named are still
# there.
if grep -q "unexpected EOF" $top/quoted-clean.out
then
    echo "the shell gave up on a distclean line partway through" >&2
    exit 1
fi
if grep -qi "syntax error" $top/quoted-clean.out
then
    echo "the shell gave up on a distclean line partway through" >&2
    exit 1
fi

# And nothing else went wrong with it either.
test "$status" = "0"

# And every directory the recipe named is gone, including the two
# whose names carry the apostrophe.
test ! -e "$top/quoted/it's/obj"
test ! -e "$top/quoted/it's/lib"
test ! -e $top/quoted/obj
test ! -e $top/quoted/Makefile

# What was not output is still there, which is what distclean promises
# and what a line the shell mangled could not have kept.
test -f "$top/quoted/it's/Configfile"
test -f "$top/quoted/it's/src/quoted.c"

##############################################################################
# Every path in a distclean is one this project owns                         #
##############################################################################
# The other half of the same sentence, and the half with more at
# stake: the quoting above settles how many directories a line
# removes, and this settles which.  The same two Configfile-written
# paths are the ones that get asked -- the directory a LIBDIR named,
# and the directory a SUBPROJECTS named.
#
# Refusals rather than warnings, which is not what this project
# usually does with a line it used to accept: strict.h++ says those
# become warnings, because a line somebody is relying on cannot
# simply stop working.  The argument for the exception is written at
# the LIBDIR in command_processor.c++ and it is about what the
# warning would cost.  What a project could be relying on here is
# "make distclean" removing a directory outside itself, and there is
# no way to have come to rely on that except by having already lost
# something to it.

##############################################################################
# A LIBDIR that names somewhere outside the project                          #
##############################################################################
# Three spellings, and each one arrives at the recipe by its own
# route.  An absolute path is in the "rm -rf" exactly as written; a
# path that climbs walks out of whatever directory make was started
# in, which is a different directory depending on who started it; and
# a make expansion is not a path at all when pconfigure reads it --
# the quotes the recipe puts around it are the shell's, and make has
# already had its turn on the line before the shell sees any of it.
mkdir -p $top/escape/src
echo 'int escape(void) { return 1; }' > $top/escape/src/escape.c

for path in "/usr/local/lib" "../lib" ".." '$(HOME)/lib'
do
    cat >$top/escape/Configfile <<EOF
LANGUAGES += c
LIBDIR = $path

LIBRARIES += libescape.so
SOURCES   += escape.c
EOF
    cat $top/escape/Configfile

    # The subshell is the assertion: "set -e" is on, so a command
    # expected to fail has to be somewhere a failure isn't fatal.
    if (cd $top/escape && $PTEST_BINARY $PCONFIGURE_ARGS) \
        > $top/escape.out 2>&1
    then
        echo "LIBDIR = $path was accepted" >&2
        exit 1
    fi
    cat $top/escape.out

    grep -q "LIBDIR names a directory outside this project" $top/escape.out

    # ... and it says what to write instead, since "no" on its own
    # leaves whoever wrote the line exactly where they started.
    grep -q "LIBDIR = lib" $top/escape.out

    # It stopped before writing anything, so there is no Makefile
    # carrying that "rm -rf" for somebody to run by hand later.
    test ! -e $top/escape/Makefile
done

# The same line refused the same way from inside the project that
# wrote it, which is the whole reason the question is asked of the
# path as written rather than of the path with this project's base on
# the front.  Based against "sub/", "/usr/local/lib" comes out as
# "sub//usr/local/lib" and climbs out of nothing -- so a check that
# resolved first would accept the line read from the top and refuse
# it read from inside, and the reading that accepts it is the one
# where "make distclean" removes /usr/local/lib.
mkdir -p $top/reading/src $top/reading/sub/src
echo 'int main(void) { return 0; }' > $top/reading/src/main.c
echo 'int escape(void) { return 1; }' > $top/reading/sub/src/escape.c

cat >$top/reading/Configfile <<'EOF'
LANGUAGES += c

SUBPROJECTS += sub

BINARIES  += main
SOURCES   += main.c
EOF

cat >$top/reading/sub/Configfile <<'EOF'
LANGUAGES += c
LIBDIR = /usr/local/lib

LIBRARIES += libescape.so
SOURCES   += escape.c
EOF

if (cd $top/reading && $PTEST_BINARY $PCONFIGURE_ARGS) \
    > $top/reading-top.out 2>&1
then
    echo "the subproject's LIBDIR was accepted, read from the top" >&2
    exit 1
fi
cat $top/reading-top.out
grep -q "LIBDIR names a directory outside this project" $top/reading-top.out

if (cd $top/reading/sub && $PTEST_BINARY $PCONFIGURE_ARGS) \
    > $top/reading-inside.out 2>&1
then
    echo "the subproject's LIBDIR was accepted, read from inside" >&2
    exit 1
fi
cat $top/reading-inside.out
grep -q "LIBDIR names a directory outside this project" $top/reading-inside.out

##############################################################################
# A LIBDIR that stays inside it is left alone                                #
##############################################################################
# The refusal is about where the path points and about nothing else.
# A project that moved its library directory somewhere inside itself
# is doing the thing the command is for, and the "rm -rf" that names
# it is a distclean doing its job.
mkdir -p $top/moved/src
echo 'int moved(void) { return 1; }' > $top/moved/src/moved.c

cat >$top/moved/Configfile <<'EOF'
LANGUAGES += c
LIBDIR = build/lib

LIBRARIES += libmoved.so
SOURCES   += moved.c
EOF

# The redirection is inside the subshell rather than on it, because
# "set -x" writes its trace to the shell's standard error and a
# subshell's trace would land in the file this is about to say is
# empty.
(cd $top/moved && $PTEST_BINARY $PCONFIGURE_ARGS > $top/moved.out 2>&1)
cat $top/moved.out
test ! -s $top/moved.out

sed -n '/^distclean:/,/^$/p' $top/moved/Makefile > $top/moved.rule
cat $top/moved.rule
grep -q "rm -rf 'build/lib'" $top/moved.rule

##############################################################################
# A SUBPROJECTS that is a symlink out of the tree                            #
##############################################################################
# Both of the checks on a SUBPROJECTS are lexical on purpose: a path
# that stays inside the project names the same directory whether
# pconfigure ran in that project or above it, and a check that
# resolved one side of the question would throw that property away.
# A symlink is where the name and the destination stop agreeing --
# "sub" is an ordinary-looking name that reaches wherever it likes --
# and "rm -rf sub/obj" follows it, because rm declines to walk
# through a symlink only when the symlink is the last thing on the
# path.
#
# So the destination is asked about as well, with both sides
# resolved, which is a question whose answer doesn't move either.
# The directory the link points at is inside the temporary directory
# rather than anywhere real, since what is under test is a refusal
# and a test that needed the refusal to work in order to be safe
# would be a bad trade.
mkdir -p $top/linked/src $top/outside/src
echo 'int main(void) { return 0; }' > $top/linked/src/main.c
echo 'int sub(void) { return 1; }' > $top/outside/src/sub.c
echo "not this build's" > $top/outside/keep.txt

cat >$top/outside/Configfile <<'EOF'
LANGUAGES += c

LIBRARIES += libsub.so
SOURCES   += sub.c
EOF

cat >$top/linked/Configfile <<'EOF'
LANGUAGES += c

SUBPROJECTS += sub

BINARIES  += main
SOURCES   += main.c
EOF

ln -s $top/outside $top/linked/sub

if (cd $top/linked && $PTEST_BINARY $PCONFIGURE_ARGS) > $top/linked.out 2>&1
then
    echo "a SUBPROJECTS symlinked out of the tree was accepted" >&2
    exit 1
fi
cat $top/linked.out

grep -q "SUBPROJECTS can't reach outside the project" $top/linked.out

# And the message names both ends, since the whole difficulty with a
# symlink is that the line as written says nothing about where it
# goes.
grep -q "resolves to" $top/linked.out

# Nothing was written, so no "rm -rf sub/obj" exists to be run.
test ! -e $top/linked/Makefile
test -f $top/outside/keep.txt

##############################################################################
# A SUBPROJECTS that is a symlink into the object directory                   #
##############################################################################
# The other lexical check, defeated the same way and with the loss
# pointing the other direction: "vendor" is not inside "obj" by its
# name, so the tree it reaches is one "rm -rf obj" away from being
# gone, and what goes with it is whatever had not been pushed.
mkdir -p $top/inobj/src $top/inobj/obj/checkout/src
echo 'int main(void) { return 0; }' > $top/inobj/src/main.c
echo 'int sub(void) { return 1; }' > $top/inobj/obj/checkout/src/sub.c

cat >$top/inobj/obj/checkout/Configfile <<'EOF'
LANGUAGES += c

LIBRARIES += libsub.so
SOURCES   += sub.c
EOF

cat >$top/inobj/Configfile <<'EOF'
LANGUAGES += c

SUBPROJECTS += vendor

BINARIES  += main
SOURCES   += main.c
EOF

ln -s obj/checkout $top/inobj/vendor

if (cd $top/inobj && $PTEST_BINARY $PCONFIGURE_ARGS) > $top/inobj.out 2>&1
then
    echo "a SUBPROJECTS symlinked into the object directory was accepted" >&2
    exit 1
fi
cat $top/inobj.out

grep -q "SUBPROJECTS can't name a directory inside an object directory" \
    $top/inobj.out
grep -q "resolves to" $top/inobj.out
test ! -e $top/inobj/Makefile

##############################################################################
# A symlink that stays inside the tree is still a subproject                 #
##############################################################################
# Which is why this asks where the link goes rather than refusing a
# link.  A tree linked into place from somewhere else in the same
# checkout is a real thing to do and there is nothing wrong with it:
# what the "rm -rf" reaches is inside the project either way, and the
# distclean it produces is an ordinary one.
mkdir -p $top/inside/src $top/inside/vendor/tree/src
echo 'int main(void) { return 0; }' > $top/inside/src/main.c
echo 'int sub(void) { return 1; }' > $top/inside/vendor/tree/src/sub.c

cat >$top/inside/vendor/tree/Configfile <<'EOF'
LANGUAGES += c

LIBRARIES += libsub.so
SOURCES   += sub.c
EOF

cat >$top/inside/Configfile <<'EOF'
LANGUAGES += c

SUBPROJECTS += sub

BINARIES  += main
SOURCES   += main.c
EOF

ln -s vendor/tree $top/inside/sub

(cd $top/inside && $PTEST_BINARY $PCONFIGURE_ARGS > $top/inside.out 2>&1)
cat $top/inside.out
test ! -s $top/inside.out

sed -n '/^distclean:/,/^$/p' $top/inside/Makefile > $top/inside.rule
cat $top/inside.rule
grep -q "rm -rf 'sub/obj'" $top/inside.rule

# And it removes what it named, through the link, leaving the tree
# the link points at otherwise alone.
mkdir -p $top/inside/vendor/tree/obj
echo "output" > $top/inside/vendor/tree/obj/stale.o

(cd $top/inside && make $MAKE_ARGS distclean) > $top/inside-clean.out 2>&1
cat $top/inside-clean.out
test ! -e $top/inside/vendor/tree/obj
test -f $top/inside/vendor/tree/Configfile
test -f $top/inside/vendor/tree/src/sub.c

exit 0
