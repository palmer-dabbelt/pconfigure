#include "harness_start.bash"
#pconfigure TESTDEPS += bin/psubdeps

# A vendored tree decides which Kconfig files it reads by reading
# them, so pconfigure's answer to that question is a guess made from
# the outside.  The tree's own answer is written down during the
# build, because its build needs one -- and this is what happens when
# the build reads it.
#
# "hidden/Kconfig" is the whole test: nothing in the tree names it in
# any file pconfigure could chase, and the tree says it read it.  A
# guess cannot find that; a build that is told can.

mkdir -p src sub/configs sub/drivers sub/hidden sub/shared

cat >Configfile <<EOF
BUILD_SYSTEMS += kconfig

SUBPROJECTS   += sub
CONFIGUREOPTS += --defconfig tiny_defconfig

LANGUAGES   += c
BINARIES    += test
SOURCES     += test.c
EOF

cat >src/test.c <<EOF
int main(void) { return 0; }
EOF

cat >sub/Kconfig <<'EOF'
config BASE
	bool "base"
	default y

source "drivers/Kconfig"
EOF

cat >sub/drivers/Kconfig <<'EOF'
config EXTRA
	bool "extra"
EOF

# Reachable only by asking the tree.
cat >sub/hidden/Kconfig <<'EOF'
config HIDDEN
	bool "hidden"
EOF

cat >sub/configs/tiny_defconfig <<'EOF'
CONFIG_BASE=y
EOF

# Two sources reached the way kbuild reaches sources, which is by
# naming an object and leaving the suffix to be guessed back.  What
# makes them interesting is below: one of them gets named twice.
cat >sub/shared/one.c <<'EOF'
int one(void) { return 1; }
EOF

cat >sub/shared/two.c <<'EOF'
int two(void) { return 2; }
EOF

# The vendored build system, which writes down what it read the way
# kbuild does: an assignment, one path a line, a backslash on the end.
cat >sub/Makefile <<'EOF'
O ?= $(CURDIR)/build

obj-y              += $(SHARED)/one.o
obj-$(CONFIG_BASE) += $(SHARED)/one.o
obj-m              += $(SHARED)/two.o

all: $(O)/.config
	@mkdir -p $(O)
	@cp $(O)/.config $(O)/built.txt

tiny_defconfig:
	@mkdir -p $(O) $(O)/include/config
	@cp $(CURDIR)/configs/tiny_defconfig $(O)/.config
	@{ printf 'autoconfig := include/config/auto.conf\n\ndeps_config := \\\n'; for f in Kconfig drivers/Kconfig hidden/Kconfig; do test -e "$(CURDIR)/$$f" && printf '\t%s \\\n' "$$f"; done; printf '\n$$(deps_config): ;\n'; } > $(O)/include/config/auto.conf.cmd
EOF

$PTEST_BINARY $PCONFIGURE_ARGS

##############################################################################
# The same guess, asked for twice                                            #
##############################################################################
# The chase cannot evaluate a variable, so it replaces one with a "*"
# and asks the filesystem instead.  That means two lines which differ
# only in a variable ask the identical question -- and a kbuild tree
# asks a handful of questions tens of thousands of times, which is why
# the answers are remembered rather than walked for again.
#
# This is here to say that remembering them did not change any of them.
# It is the shape a memo can get wrong: the second ask is the one served
# out of the table rather than off the disk, and a table that handed
# back the wrong list, or an empty one, would look like a tree that had
# quietly stopped depending on half of itself.
#
# The fixture is two lines of sub/Makefile that both name one.o, and
# both name it through the same $(SHARED).  What differs between them
# is the left-hand side -- "obj-y" on one, "obj-$(CONFIG_BASE)" on the
# other -- so the two lines are different lines asking the identical
# question, and the second one is the ask that gets served out of the
# table.  two.o is named once and is the control.
#
# So the whole prerequisite list is what gets compared, rather than a
# count of the one or two names somebody was thinking about at the
# time.  That is not fussiness: the version of this test that counted
# one.c and two.c passed against a memo poisoned to return an empty
# list on every hit, because the first, uncached ask had already
# contributed both of them and what the poison actually dropped was
# sub/Kconfig -- the root Kconfig the entire fixture hangs off, and a
# name neither of those two counts ever looked at.  A memo that drops a
# name, or invents one, fails this instead.
#
# A memo that handed the same list back twice does not, and saying so
# is worth more than a claim that sounds stronger.  What collects these
# answers keeps them in a set, so duplicates are gone before they reach
# the Makefile and no assertion on the Makefile can see them.  The two
# shapes this pins are a name that went missing and a name that was
# never there, which are the two that change what gets built.
#
# The list is sorted before it is compared.  Ordering here comes out of
# glob(3) and out of the order the lines were read, and pinning that
# would be pinning the filesystem rather than the memo.  Sorted under
# LC_ALL=C, because the default collation on this machine folds case
# and puts "sub/Kconfig" after "sub/configs", which would make the
# expected list below a statement about whoever's locale ran it.
#
# Not a count of globs and not a stopwatch.  What the memo bought is in
# the commit that added it and belongs there; a test that asserted a
# ratio would be a test that fails on a busy machine and teaches
# whoever it wakes up nothing.  What is asserted is that the answer is
# the same answer, which is the only thing an optimisation owes anyone
# -- and it is asserted so that it still holds with the memo taken back
# out again.
#
# The head of the rule is pinned separately from the guessed list
# because they are two different claims: the configuration the vendored
# build hangs off is named outright, and everything the chase guessed
# at is named through a "$(wildcard ...)" -- a guess names files that
# may since have gone away, so it asks whether they are there rather
# than stopping the build on them.
grep -q '^obj/sub/build-stamp: obj/sub/build/\.config \$(wildcard [^)]*)$' Makefile
test "$(grep '^obj/sub/build-stamp:' Makefile \
        | sed -n 's/.*\$(wildcard \([^)]*\)).*/\1/p' \
        | tr ' ' '\n' | LC_ALL=C sort | xargs)" \
     = "sub/Kconfig sub/Makefile sub/configs/tiny_defconfig \
sub/drivers/Kconfig sub/hidden/Kconfig sub/shared/one.c sub/shared/two.c"

##############################################################################
# What the Makefile says before anything has been built                      #
##############################################################################
# The fragment is included, and it is a file this Makefile knows how
# to build -- which is what lets make bring it into existence rather
# than stopping on it.
grep -q "^include obj/sub/config-deps.mk$" Makefile
grep -q '^obj/sub/config-deps.mk: obj/sub/config-deps-context \$(wildcard /[^ )]*/psubdeps)$' Makefile

# Two prerequisites, and neither of them is a file this Makefile
# builds.  That is what makes the remaking terminate: the fragment can
# go out of date at most once per configure.
#
# The first is a file pconfigure wrote.  The second is psubdeps
# itself, which is there because the fragment is not the tree it
# describes -- it is what one version of psubdeps made of what that
# tree said it read, so a psubdeps that has learned to see something
# new has to be able to say so.  It does not cost the argument above
# anything: pconfigure names it by the absolute path it resolved the
# tool to, make has no rule under that spelling even in a tree that
# vendors and builds pconfigure, and a prerequisite with no rule is a
# timestamp and cannot go out of date while a make is running.
#
# Keep the "$" on the end of that pattern.  It is the assertion: the
# whole prerequisite list is what is being pinned, and a grep that
# matched a prefix would go on passing while the list quietly grew a
# file the build does produce -- which is the one thing that would
# start the remaking over and not stop.  The spelling is being pinned
# too, and pinned as an absolute path -- the leading "/" is there on
# purpose -- for the reason written out over language_cxx::deps_source():
# the relative in-tree spelling of the same binary is the one that
# makes make link pconfigure before it has read the fragments saying
# what to link it out of.  A pattern of ".*/psubdeps" would be happy
# with "bin/psubdeps", which is exactly the spelling this exists to
# rule out.
#
# And keep the pattern in single quotes.  It shipped once in double
# quotes with the dollar written as "\\$", which bash reads as a
# backslash followed by a command substitution: the shell ran a
# command called "wildcard", printed "wildcard: command not found" on
# every run, and handed grep a pattern that ended at "context $" --
# no end anchor and no mention of psubdeps at all.  It passed against
# the relative spelling and against a prerequisite that was simply
# the wrong variable.  Single quotes are what bootstrap-quiet.bash
# does, and why bootstrap-quiet.bash was right.
test -e obj/sub/config-deps-context

# And the guess has not got the hidden one, which is the point.
if grep "^obj/sub/build/.config:" Makefile | grep -q "hidden"
then
    exit 1
fi

# The two rules that run the vendored build system do not name
# psubdeps, and that is on purpose rather than an oversight nobody got
# to.  Their recipes end by running it -- the answer arrives in the
# same make that produced it, which is what the rewrite at the end of
# the recipe is for -- but running a tool is not the same as being out
# of date when it changes.  Making it a prerequisite here would mean
# every edit to pconfigure reconfigures and rebuilds the whole
# vendored tree, which for the trees this exists for is a kernel and a
# buildroot and the better part of an afternoon.  Nothing is lost by
# leaving it out: the fragments above name psubdeps, so they re-derive
# on their own, and re-deriving them is the entire difference a new
# psubdeps could make.
#
# Written down as a test because it is the kind of asymmetry that
# looks like a bug to the next person who reads the two rules side by
# side, and closing it "for consistency" costs hours per build and
# shows up as nothing except a tree that got slow.
if grep "^obj/sub/build/.config:" Makefile | grep -q "psubdeps"
then
    exit 1
fi
if grep "^obj/sub/build-stamp:" Makefile | grep -q "psubdeps"
then
    exit 1
fi

##############################################################################
# One build                                                                  #
##############################################################################
make $MAKE_ARGS > build.log 2>&1
cat build.log

# The tree has been configured, so it has said what it read, so the
# fragment says it too -- all in the one make.  This is what the
# rewrite at the end of the recipe is for: without it the answer would
# not arrive until somebody ran make a second time.
cat obj/sub/config-deps.mk
grep -q "^obj/sub/build/.config:.*sub/hidden/Kconfig" obj/sub/config-deps.mk
grep -q "^sub/hidden/Kconfig:$" obj/sub/config-deps.mk

##############################################################################
# A second make                                                              #
##############################################################################
# Which does nothing.  A fragment that came out of a rule the build
# runs is a fragment that could keep making itself out of date, so
# this is the assertion that says it does not.
make $MAKE_ARGS > second.log 2>&1
cat second.log
grep -q "Nothing to be done" second.log

##############################################################################
# A file only the tree knew about                                            #
##############################################################################
# The whole point of reading what the tree said: editing this used to
# change nothing, because nothing in the build had heard of it.
sleep 1
touch sub/hidden/Kconfig

make $MAKE_ARGS > third.log 2>&1
cat third.log
grep -q "KCONFIG" third.log

# And it settles again.
make $MAKE_ARGS > fourth.log 2>&1
cat fourth.log
grep -q "Nothing to be done" fourth.log

##############################################################################
# A file only the tree knew about, deleted                                   #
##############################################################################
# Each path gets a rule with nothing in it, so a file that has gone
# away is a reason to configure the tree again rather than a build
# that stops on a prerequisite nothing knows how to make.  These are
# safe here in a way they would not be on an included makefile,
# because what they hang off is an ordinary target.
sleep 1
rm sub/hidden/Kconfig

make $MAKE_ARGS > fifth.log 2>&1
cat fifth.log
grep -q "KCONFIG" fifth.log

# The tree, asked again, no longer says it read it, so the fragment
# stops naming it -- and the guessed list in the Makefile names it
# through $(wildcard), so it stops being a prerequisite too.  One
# reconfigure, then quiet.
if grep -q "hidden" obj/sub/config-deps.mk
then
    exit 1
fi

make $MAKE_ARGS > sixth.log 2>&1
cat sixth.log
grep -q "Nothing to be done" sixth.log

exit 0
