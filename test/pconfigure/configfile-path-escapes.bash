#include "harness_start.bash"

top="$tempdir"

##############################################################################
# A path that climbs out of the project, in both of its spellings            #
##############################################################################
# Every command that names a path is asked one question about it --
# does it stay inside the project that wrote it -- and the answer is
# leaves_the_project()'s rather than each command's own.  One place
# rather than several, because a command that asked it in its own
# words was a command that asked it slightly differently: the bare
# ".." is what a check written as "starts with '../'" lets past,
# there being no trailing slash on it for that to match.
#
# It is also the worst spelling there is.  "../out" names a directory
# beside the project; ".." names the directory the project was
# checked out into, which is everything.

##############################################################################
# TESTDEPS                                                                   #
##############################################################################
# A TESTDEPS is a prerequisite of a test, so a path that climbs out
# arrives in the Makefile as a prerequisite naming somewhere else
# entirely -- "check/main/t.bash: bin/main obj/check/main/t.bash .."
# is a test that waits on the directory the checkout sits in.
mkdir -p $top/testdeps/src $top/testdeps/test/main
echo 'int main(void) { return 0; }' > $top/testdeps/src/main.c
echo 'true' > $top/testdeps/test/main/t.bash

for path in ".." "../x" "/usr/bin/true"
do
    cat >$top/testdeps/Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash

BINARIES  += main
TESTDEPS  += $path
SOURCES   += main.c
TESTSRC   += t.bash
EOF
    cat $top/testdeps/Configfile

    # The subshell is the assertion: "set -e" is on, so a command
    # expected to fail has to be somewhere a failure isn't fatal.
    if (cd $top/testdeps && $PTEST_BINARY $PCONFIGURE_ARGS) \
        > $top/testdeps.out 2>&1
    then
        echo "TESTDEPS += $path was accepted" >&2
        exit 1
    fi
    cat $top/testdeps.out

    grep -q "TESTDEPS can't reach outside the project" $top/testdeps.out

    # The message says which of the spellings was written, since
    # three things are refused here for three different reasons and a
    # refusal that named none of them leaves the reader working out
    # which one they wrote.
    grep -q "it climbs out of the project\|it's an absolute path" \
        $top/testdeps.out

    # ... and what to do instead, which is the part a refusal is no
    # use without.
    grep -q "link line" $top/testdeps.out

    test ! -e $top/testdeps/Makefile
done

# And the ordinary spelling still works, since what is refused is
# where the path points rather than that a TESTDEPS was written.
cat >$top/testdeps/Configfile <<'EOF'
LANGUAGES += c
LANGUAGES += bash

TESTEXECS += tool
SOURCES   += tool.c

BINARIES  += main
TESTDEPS  += testexec/tool
SOURCES   += main.c
TESTSRC   += t.bash
EOF

echo 'int main(void) { return 0; }' > $top/testdeps/src/tool.c

(cd $top/testdeps && $PTEST_BINARY $PCONFIGURE_ARGS > $top/testdeps-ok.out 2>&1)
cat $top/testdeps-ok.out
test ! -s $top/testdeps-ok.out
grep -q "^check/main/t.bash:.* testexec/tool" $top/testdeps/Makefile

##############################################################################
# DEPTESTS                                                                   #
##############################################################################
# The same question of the same shape one command over.  A bare ".."
# here was already refused, but by the rule further down that a
# DEPTESTS names a test this target actually has -- so it came back
# as a test that couldn't be found rather than as a path that left
# the project, and sent whoever read it looking for a missing file.
mkdir -p $top/deptests/src $top/deptests/test/main
echo 'int main(void) { return 0; }' > $top/deptests/src/main.c
echo 'true' > $top/deptests/test/main/a.bash
echo 'true' > $top/deptests/test/main/b.bash

for path in ".." "../other/far.bash" "/check/main/a.bash"
do
    cat >$top/deptests/Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash

BINARIES  += main
SOURCES   += main.c
TESTSRC   += a.bash
TESTSRC   += b.bash
DEPTESTS  += $path
EOF
    cat $top/deptests/Configfile

    if (cd $top/deptests && $PTEST_BINARY $PCONFIGURE_ARGS) \
        > $top/deptests.out 2>&1
    then
        echo "DEPTESTS += $path was accepted" >&2
        exit 1
    fi
    cat $top/deptests.out

    grep -q "DEPTESTS can't reach outside the target" $top/deptests.out
    grep -q "it climbs out of the project\|it's an absolute path" \
        $top/deptests.out
    grep -q "put both under a PHONY" $top/deptests.out

    # And not the other rule's answer, which is the whole of what the
    # bare ".." used to come back as.
    if grep -q "which is no test of this target" $top/deptests.out
    then
        echo "DEPTESTS += $path was reported as a missing test" >&2
        exit 1
    fi

    test ! -e $top/deptests/Makefile
done

# The ordinary spelling, again: one test of this target waiting on
# another one of the same target.
cat >$top/deptests/Configfile <<'EOF'
LANGUAGES += c
LANGUAGES += bash

BINARIES  += main
SOURCES   += main.c
TESTSRC   += a.bash
TESTSRC   += b.bash
DEPTESTS  += a.bash
EOF

(cd $top/deptests && $PTEST_BINARY $PCONFIGURE_ARGS > $top/deptests-ok.out 2>&1)
cat $top/deptests-ok.out
test ! -s $top/deptests-ok.out
grep -q "^check/main/b.bash:.* check/main/a.bash" $top/deptests/Makefile

##############################################################################
# SRCDIR gets the question and a different answer                            #
##############################################################################
# A SRCDIR that climbs out is the same line meaning two directories,
# and it is a warning rather than a refusal.  The difference is what
# the path reaches: a LIBDIR is pasted into "make distclean"'s
# "rm -rf", while a source directory is only ever read.  The worst a
# SRCDIR out there does is write an object out there too -- an
# object's path is its source's pasted onto the object directory --
# which is a line doing something nobody meant and taking nothing
# with it, which is exactly what strict.h++ says to warn about.
mkdir -p $top/srcdir/proj $top/srcdir/shared
echo 'int main(void) { return 0; }' > $top/srcdir/shared/main.c

cat >$top/srcdir/proj/Configfile <<'EOF'
LANGUAGES += c

SRCDIR = ../shared

BINARIES  += main
SOURCES   += main.c
EOF

(cd $top/srcdir/proj && $PTEST_BINARY $PCONFIGURE_ARGS > $top/srcdir.out 2>&1)
cat $top/srcdir.out

grep -q "warning: SRCDIR names a directory outside this project" $top/srcdir.out
grep -q "it climbs out of the project" $top/srcdir.out
grep -q "SRCDIR = src" $top/srcdir.out

# A warning rather than a refusal means the Makefile is there, which
# is the half of "warning" that matters to whoever is relying on the
# line.
test -e $top/srcdir/proj/Makefile

# And a project that would rather be told loudly says so, which is
# the whole of what STRICT is for.
cat >$top/srcdir/proj/Configfile <<'EOF'
STRICT = v0.13

LANGUAGES += c

SRCDIR = ../shared

BINARIES  += main
SOURCES   += main.c
EOF

rm -f $top/srcdir/proj/Makefile

if (cd $top/srcdir/proj && $PTEST_BINARY $PCONFIGURE_ARGS) \
    > $top/srcdir-strict.out 2>&1
then
    echo "an escaping SRCDIR was accepted under STRICT = v0.13" >&2
    exit 1
fi
cat $top/srcdir-strict.out
grep -q "error: SRCDIR names a directory outside this project" \
    $top/srcdir-strict.out
test ! -e $top/srcdir/proj/Makefile

# A SRCDIR that stays inside says nothing at all, which is what says
# this is about where the path points rather than about the command.
mkdir -p $top/srcdir/quiet/elsewhere
echo 'int main(void) { return 0; }' > $top/srcdir/quiet/elsewhere/main.c

cat >$top/srcdir/quiet/Configfile <<'EOF'
LANGUAGES += c

SRCDIR = elsewhere

BINARIES  += main
SOURCES   += main.c
EOF

(cd $top/srcdir/quiet && $PTEST_BINARY $PCONFIGURE_ARGS > $top/quiet.out 2>&1)
cat $top/quiet.out
test ! -s $top/quiet.out

##############################################################################
# And the two directory commands that aren't there                           #
##############################################################################
# The comments around this rule name the commands that move an output
# directory, and they used to name two that don't exist: an OBJDIR,
# which nothing in this pconfigure has ever read, and a HDRDIR, which
# is a name in the enum and nothing else.  A comment that names a
# command sends whoever reads it looking for that command, so the
# claim is worth an assertion rather than a promise.
mkdir -p $top/missing/src
echo 'int main(void) { return 0; }' > $top/missing/src/main.c

cat >$top/missing/Configfile <<'EOF'
LANGUAGES += c

OBJDIR = build

BINARIES  += main
SOURCES   += main.c
EOF

if (cd $top/missing && $PTEST_BINARY $PCONFIGURE_ARGS) > $top/objdir.out 2>&1
then
    echo "OBJDIR is a command after all" >&2
    exit 1
fi
cat $top/objdir.out
grep -q "Unable to process OBJDIR as command_type" $top/objdir.out

cat >$top/missing/Configfile <<'EOF'
LANGUAGES += c

HDRDIR = hdr

BINARIES  += main
SOURCES   += main.c
EOF

if (cd $top/missing && $PTEST_BINARY $PCONFIGURE_ARGS) > $top/hdrdir.out 2>&1
then
    echo "HDRDIR does something after all" >&2
    exit 1
fi
cat $top/hdrdir.out
grep -q "Command HDRDIR not implemented" $top/hdrdir.out

exit 0
