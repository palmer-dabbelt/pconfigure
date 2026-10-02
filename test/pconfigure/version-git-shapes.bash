#include "harness_start.bash"

# src/version.h.proc answers two questions about git -- what the
# version is, and which files the answer turns on -- and for a long
# time it got both of them wrong in the same way, by deciding whether
# there was any git at all with "test -d .git".
#
# A ".git" that is a FILE rather than a directory is a "gitdir:"
# pointer at a repository kept elsewhere, and git writes one for a
# submodule and for a linked worktree.  So in the tree this test was
# written in, where pconfigure is a submodule of a superproject,
# "--deps" printed nothing whatsoever and "--generate" printed the
# hardcoded fallback while "git describe" in the same directory named
# a commit.  The output encoded a verdict about an input the dependency
# list did not mention -- a cache with no key -- which is the same
# shape as the bug the '?' convention was added for, and this file is
# the fourth place it was found.
#
# What this pins is the script's answers, one git shape at a time,
# because the shapes are where it went wrong rather than the
# arithmetic.  version-git-deps.bash pins what a build does with those
# answers.
#
# Every shape is asked two things beyond its own particulars.  That no
# line is an absolute path: pconfigure records a dependency as the
# owning project's prefix with the printed path on the end, so an
# absolute one arrives in the Makefile as "src/pconfigure//home/..."
# and is the one escape from the project that cannot be expressed.  And
# that no line says "master", which the old file fell back to by name
# -- this project's branch is "master" today, which is exactly why a
# hardcoded one went unnoticed, so the fixtures here deliberately use
# some other name.

proc="$PTEST_SRCDIR/src/version.h.proc"
test -x "$proc"

# git is a hard requirement of this test, not something it tiptoes
# around.  ptest has no skip verdict -- a test that exits 0 passed --
# so "quietly do nothing when the tool is missing" is a pass that
# measured nothing, which is precisely the accounting failure that let
# the original bug sit for days.  A machine with no git gets a
# failure it can see.
command -v git > /dev/null

# A hermetic git: no identity to borrow from the machine, no global or
# system config to change the default branch or hook anything, and no
# reliance on "git init -b" so that the branch name is pinned the same
# way on every git old enough to run at all.
export GIT_AUTHOR_NAME="ptest"
export GIT_AUTHOR_EMAIL="ptest@invalid"
export GIT_COMMITTER_NAME="ptest"
export GIT_COMMITTER_EMAIL="ptest@invalid"
export GIT_CONFIG_NOSYSTEM="1"
export HOME="$tempdir/home"
mkdir -p "$HOME"

# The version the script hardcodes, read out of the script rather than
# written down here: it refuses a "git describe" whose first field
# disagrees with it, so every fixture below has to carry that exact
# tag, and a copy of the number in this file would be a test that
# breaks on the next release instead of the next regression.
version="$(sed -n 's/^version="\(.*\)"$/\1/p' "$proc")"
test "$version" != ""

# A repository with a tag the script will accept and one commit past
# it, so that "git describe" has a distance and an abbreviated sha in
# it and a wrong answer cannot look like a right one.
mkrepo() # $1 directory, $2 branch name
{
    mkdir -p "$1"
    (
        cd "$1"
        git init -q .
        git symbolic-ref HEAD "refs/heads/$2"
        git commit -q --allow-empty -m one
        git tag -a "$version" -m tag
        git commit -q --allow-empty -m two
    )
}

# What every shape is asked.  $1 is the deps output.
no_absolute_and_no_master()
{
    if grep -q '^?*/' "$1"
    then
        exit 1
    fi

    if grep -q 'master' "$1"
    then
        exit 1
    fi
}

##############################################################################
# A plain clone: ".git" is a directory                                       #
##############################################################################
# The shape that always worked, so the point here is the three lines
# rather than their existence: each is optional, and the branch is
# named by asking git rather than by guessing.
mkrepo plain trunk
(
    cd plain

    bash "$proc" --deps > deps.out
    cat deps.out
    no_absolute_and_no_master deps.out

    grep -qxF '?.git/HEAD' deps.out
    grep -qxF '?.git/refs/heads/trunk' deps.out
    grep -qxF '?.git/packed-refs' deps.out
    test "$(grep -c . deps.out)" = "3"

    # A fresh repository has no packed-refs file at all, and the line is
    # printed anyway.  That is the whole of what '?' buys over the
    # "test -f" guard it replaces: the old file left the line out,
    # so a tree configured before its first "git gc" watched a loose
    # ref that packing was about to delete and watched nothing at all
    # of the file the ref moved into.
    test ! -e .git/packed-refs

    bash "$proc" --generate > gen.out
    cat gen.out
    grep -q "^#define PCONFIGURE_VERSION \"$version-1-g.*-git\"\$" gen.out
)

##############################################################################
# A gitlink: ".git" is a file, the repository is outside the project          #
##############################################################################
# The regression this file exists for.  A relative path that leaves the
# project through ".." is fine -- make stats the name it is given and
# does not care where it points -- and it is what this tree is actually
# in, the real git directory of a submodule living in the superproject
# at ../../.git/modules/<path>.  The ".."s also come out at the right
# depth for the prefixing pconfigure does, which version-git-deps.bash
# measures from a parent's make.
# "--separate-git-dir" will create the repository but not the
# directories above it, so the superproject's .git/modules is laid out
# by hand -- the same layout "git submodule add" produces.
mkdir -p super/src super/.git/modules/src
git init -q --separate-git-dir="$tempdir/super/.git/modules/src/proj" \
    super/src/proj
(
    cd super/src/proj
    git symbolic-ref HEAD refs/heads/trunk
    git commit -q --allow-empty -m one
    git tag -a "$version" -m tag
    git commit -q --allow-empty -m two

    # The shape itself, said out loud: a reader who finds this test
    # failing should be able to tell whether the fixture still is what
    # it claims to be.
    test -f .git
    test ! -d .git

    bash "$proc" --deps > deps.out
    cat deps.out
    no_absolute_and_no_master deps.out

    grep -qxF '?../../.git/modules/src/proj/HEAD' deps.out
    grep -qxF '?../../.git/modules/src/proj/refs/heads/trunk' deps.out
    grep -qxF '?../../.git/modules/src/proj/packed-refs' deps.out
    test "$(grep -c . deps.out)" = "3"

    # And the half the dependency half is meaningless without: the old
    # file returned before reaching any of it, so this printed the
    # fallback with a straight face.
    bash "$proc" --generate > gen.out
    cat gen.out
    grep -q "^#define PCONFIGURE_VERSION \"$version-1-g.*-git\"\$" gen.out
)

##############################################################################
# A linked worktree: ".git" is a file, HEAD is per-worktree                   #
##############################################################################
# The other shape that writes a ".git" file, and the one that tells the
# two git directories apart: HEAD lives in the per-worktree directory
# and the branch refs and packed-refs live in the common one, so a
# script that asked for only one of them would watch the wrong file for
# two of the three lines.
mkrepo wtmain trunk
(
    cd wtmain
    git worktree add -q "$tempdir/wtlinked" -b side
)
(
    cd wtlinked
    test -f .git
    test ! -d .git

    bash "$proc" --deps > deps.out
    cat deps.out
    no_absolute_and_no_master deps.out

    grep -qxF '?../wtmain/.git/worktrees/wtlinked/HEAD' deps.out
    grep -qxF '?../wtmain/.git/refs/heads/side' deps.out
    grep -qxF '?../wtmain/.git/packed-refs' deps.out
    test "$(grep -c . deps.out)" = "3"

    bash "$proc" --generate > gen.out
    cat gen.out
    grep -q "^#define PCONFIGURE_VERSION \"$version-1-g.*-git\"\$" gen.out
)

##############################################################################
# No git at all: a release tarball                                            #
##############################################################################
# The case the hardcoded fallback is for, and the one a fix that merely
# asked git harder would have broken.
mkdir -p tarball
(
    cd tarball

    bash "$proc" --deps > deps.out 2> deps.err
    cat deps.out deps.err
    test ! -s deps.out
    test ! -s deps.err

    bash "$proc" --generate > gen.out
    cat gen.out
    grep -qxF "#define PCONFIGURE_VERSION \"$version\"" gen.out
)

##############################################################################
# A copy of this project inside somebody else's checkout                      #
##############################################################################
# "git rev-parse" answers for whatever repository encloses the current
# directory, and here that is the wrong repository: its tags are some
# other project's.  "test -d .git" refused this by accident, and the
# refusal has to survive the fix -- without it "git describe" answers
# with the host's tag, the mismatch check in the script turns that into
# a non-zero exit, and a build that was merely reporting a dull version
# stops instead.  So this asks for the exit status as well as the
# string.
mkrepo host main
mkdir -p host/vendor/proj
(
    cd host
    git tag -a "v9.9.9" -m other
)
(
    cd host/vendor/proj

    bash "$proc" --deps > deps.out
    cat deps.out
    test ! -s deps.out

    # The status is captured rather than left to "set -e", which would
    # abort this test on the very failure it is here to prove does not
    # happen and report it as something else.
    rc="0"
    bash "$proc" --generate > gen.out || rc="$?"
    cat gen.out
    test "$rc" = "0"
    grep -qxF "#define PCONFIGURE_VERSION \"$version\"" gen.out
    if grep -q "9.9.9" gen.out
    then
        exit 1
    fi
)

exit 0
