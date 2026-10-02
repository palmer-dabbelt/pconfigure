#include "harness_start.bash"

# What a build does with the git dependencies src/version.h.proc
# declares.  version-git-shapes.bash pins the answers; this pins the
# two things that go wrong between the answer and the Makefile, and
# both of them were measured against the file this replaces rather
# than imagined.
#
# One: a submodule's real git directory is OUTSIDE the project, at
# ../../.git/modules/<path> of the superproject, and the path has to
# survive pconfigure writing it down as the subproject's prefix with
# the printed path on the end.  That it comes out right is arithmetic
# -- the ".."s are exactly as deep as the project is below the
# superproject -- but it is arithmetic nobody should have to redo, and
# getting it wrong produces a Makefile that is perfectly valid and
# names the wrong file.
#
# Two: the loose ref the snapshot names is a file git deletes on its
# own.  "git gc" packs refs, and so does any "git pack-refs"; the old
# file named the loose ref outright, as a prerequisite nothing builds,
# so routine git housekeeping stopped the whole build:
#
#     make: *** No rule to make target '.git/refs/heads/trunk',
#     needed by 'obj/proc/version.h'.  Stop.
#
# That is not version.h failing to rebuild, it is every target in the
# tree, which is why it is pinned by a build rather than by reading the
# Makefile.
#
# Both halves use the real src/version.h.proc, copied in.  A stand-in
# here would be testing the stand-in: what is under test is the
# agreement between what that script prints and what pconfigure makes
# of it.

proc="$PTEST_SRCDIR/src/version.h.proc"
test -x "$proc"

# git is a hard requirement rather than something to tiptoe around --
# see version-git-shapes.bash for why a quiet skip would be the wrong
# answer in this particular file.
command -v git > /dev/null

export GIT_AUTHOR_NAME="ptest"
export GIT_AUTHOR_EMAIL="ptest@invalid"
export GIT_COMMITTER_NAME="ptest"
export GIT_COMMITTER_EMAIL="ptest@invalid"
export GIT_CONFIG_NOSYSTEM="1"
export HOME="$tempdir/home"
mkdir -p "$HOME"

# Read out of the script for the same reason version-git-shapes.bash
# reads it: the script refuses a describe whose first field disagrees,
# so the fixtures have to carry this exact tag, and a copy of the
# number here would break on the next release rather than on the next
# regression.
version="$(sed -n 's/^version="\(.*\)"$/\1/p' "$proc")"
test "$version" != ""

# A C file that prints the version it was compiled against, so that
# "did the generated header actually change" is answered by running
# something rather than by reading a file the build may not have
# looked at.
write_project() # $1 project directory
{
    mkdir -p "$1/src"
    cp "$proc" "$1/src/version.h.proc"
    chmod +x "$1/src/version.h.proc"

    cat > "$1/Configfile" <<'EOF'
LANGUAGES += c

GENERATE  += version.h

BINARIES  += app
SOURCES   += app.c
EOF

    cat > "$1/src/app.c" <<'EOF'
  #include "version.h"
  #include <stdio.h>
int main(void) { printf("%s\n", PCONFIGURE_VERSION); return 0; }
EOF
}

##############################################################################
# A gitlink subproject, built from the parent                                 #
##############################################################################
# The shape of this tree: a superproject with its own ".git" directory,
# and at src/proj a project whose ".git" is a file pointing back up
# into it.
mkdir -p super
(
    cd super
    git init -q .
    git symbolic-ref HEAD refs/heads/main
    git commit -q --allow-empty -m super
)

# "--separate-git-dir" creates the repository but not the directories
# above it, so .git/modules is laid out by hand -- the same layout
# "git submodule add" produces.
mkdir -p super/.git/modules/src
git init -q --separate-git-dir="$tempdir/super/.git/modules/src/proj" \
    super/src/proj
write_project super/src/proj
(
    cd super/src/proj
    git symbolic-ref HEAD refs/heads/trunk
    git commit -q --allow-empty -m one
    git tag -a "$version" -m tag

    test -f .git
    test ! -d .git
)

cat > super/Configfile <<'EOF'
SUBPROJECTS += src/proj
EOF

cd super

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# The build is asked before the Makefile is read, deliberately: a
# failure here is the behaviour rather than the spelling.
timeout 120 make $MAKE_ARGS > first.out 2>&1 || { cat first.out; exit 1; }
cat first.out

if grep -q "No rule to make target" first.out
then
    exit 1
fi

# The version carries a commit.  This is the regression: the old file
# printed the hardcoded fallback here, because a ".git" that is a file
# is not a directory and that was the whole of its test.
./src/proj/bin/app
test "$(./src/proj/bin/app)" = "$version-git"

# The prerequisite the parent recorded, spelled all the way out, since
# a future change could break the arithmetic while still writing a
# valid Makefile.  The subproject's variable carries the path down to
# src/proj/ and the ".."s climb back out of it, so the name make stats
# is the superproject's own .git -- inside the build, for all that the
# path leaves the project.
cat src/proj/obj/proc/version.h.d
grep -qxF '$(pconfigure_subdir_src_proj)obj/proc/version.h: $(foreach f,$(wildcard $(pconfigure_subdir_src_proj)../../.git/modules/src/proj/HEAD),$(if $(realpath $(f)),$(f),))' src/proj/obj/proc/version.h.d
grep -qxF '$(pconfigure_subdir_src_proj)obj/proc/version.h: $(foreach f,$(wildcard $(pconfigure_subdir_src_proj)../../.git/modules/src/proj/refs/heads/trunk),$(if $(realpath $(f)),$(f),))' src/proj/obj/proc/version.h.d

# And it is live, which is the only thing that makes the spelling worth
# anything: a commit in the submodule moves the version on the next
# plain make from the top, with no reconfigure.
(
    cd src/proj
    git commit -q --allow-empty -m two
)

timeout 120 make $MAKE_ARGS > second.out 2>&1 || { cat second.out; exit 1; }
cat second.out
grep -q "GEN" second.out

./src/proj/bin/app
test "$(./src/proj/bin/app)" != "$version-git"
./src/proj/bin/app | grep -q "^$version-1-g.*-git\$"

# And it settles, because a prerequisite reached through "$(wildcard)"
# and a ".." is a fine way to build forever if the filter drops it on
# every pass.
timeout 120 make $MAKE_ARGS > settled.out 2>&1 || { cat settled.out; exit 1; }
cat settled.out
grep -q "Nothing to be done" settled.out

cd "$tempdir"

##############################################################################
# git packs the ref away under a configured build                             #
##############################################################################
mkdir -p plain
write_project plain
(
    cd plain
    git init -q .
    git symbolic-ref HEAD refs/heads/trunk
    git commit -q --allow-empty -m one
    git tag -a "$version" -m tag
)

cd plain

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

timeout 120 make $MAKE_ARGS > built.out 2>&1 || { cat built.out; exit 1; }
cat built.out
test "$(./bin/app)" = "$version-git"

# The fixture, said out loud: the ref the snapshot names is loose now
# and is about to stop existing.
test -f .git/refs/heads/trunk
git pack-refs --all
test ! -e .git/refs/heads/trunk

# Which used to be the end of the build.  Now the prerequisite that
# lost its file is simply not named, the one that gained a file
# (packed-refs) is, and make has work to do rather than a reason to
# stop.
timeout 120 make $MAKE_ARGS > packed.out 2>&1 || { cat packed.out; exit 1; }
cat packed.out

if grep -q "No rule to make target" packed.out
then
    exit 1
fi

test "$(./bin/app)" = "$version-git"

# Still live afterwards: with the ref packed, what a commit moves is
# packed-refs rather than the loose file, and the old "test -f" guard
# left packed-refs out of the answer entirely whenever it did not
# happen to exist at configure time.
git commit -q --allow-empty -m two
timeout 120 make $MAKE_ARGS > repacked.out 2>&1 || { cat repacked.out; exit 1; }
cat repacked.out
./bin/app
./bin/app | grep -q "^$version-1-g.*-git\$"

timeout 120 make $MAKE_ARGS > resettled.out 2>&1 || { cat resettled.out; exit 1; }
cat resettled.out
grep -q "Nothing to be done" resettled.out

exit 0
