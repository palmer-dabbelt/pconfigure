#include "harness_start.bash"

mkdir -p sub/configs router/configs router/package/busybox

# Two vendored trees, each pulled in the way any other subproject is:
# everything below a "SUBPROJECTS" is about that one tree, which is
# why the second one gets a SUBPROJECTS of its own.  Nothing else is
# in this project, because what's under test is a file pconfigure
# writes about somebody else's build system and no amount of C on
# this side of the fence would say anything about it.
#
# What's asked for here is a defconfig, a variable on the sub-make's
# command line and a variable in its environment: three things that
# end up in three different places in a recipe, and none of which is
# a file, so none of which make could have noticed changing on its
# own.
cat >Configfile <<'EOF'
BUILD_SYSTEMS += kconfig
BUILD_SYSTEMS += buildroot

SUBPROJECTS   += sub
CONFIGUREOPTS += --defconfig tiny_defconfig
CONFIGUREOPTS += --make-var MY_VAR=first
CONFIGUREOPTS += --env MY_ENV=one

SUBPROJECTS   += router
CONFIGUREOPTS += --defconfig br_defconfig
EOF

##############################################################################
# A tree that looks enough like kbuild to be worth chasing                   #
##############################################################################
cat >sub/Kconfig <<'EOF'
config BASE
	bool "base"
	default y
EOF

cat >sub/configs/tiny_defconfig <<'EOF'
CONFIG_BASE=y
EOF

cat >sub/configs/other_defconfig <<'EOF'
CONFIG_OTHER=y
EOF

# "all" is first on purpose: a sub-make that was handed no target at
# all runs whichever target the tree's Makefile happens to mention
# first, so a tree whose defconfig rule came first would configure
# itself when it was asked to build.
#
# Everything this tree was told gets written back out where the test
# can read it, since the question in every section below is whether a
# second configure run reached the tree at all.  A variable that make
# was handed on its command line and a variable that was never set
# look the same from out here unless the tree says which one it saw.
cat >sub/Makefile <<'EOF'
O ?= $(CURDIR)/build

all: $(O)/.config
	@mkdir -p $(O)
	@cp $(O)/.config $(O)/built.txt
	@echo "MY_VAR=$(MY_VAR)" >> $(O)/built.txt
	@echo "EXTRA_VAR=$(EXTRA_VAR)" >> $(O)/built.txt
	@echo "CROSS_COMPILE=$(CROSS_COMPILE)" >> $(O)/built.txt

tiny_defconfig:
	@mkdir -p $(O)
	@cp $(CURDIR)/configs/tiny_defconfig $(O)/.config

other_defconfig:
	@mkdir -p $(O)
	@cp $(CURDIR)/configs/other_defconfig $(O)/.config
EOF

##############################################################################
# A tree that looks enough like buildroot to be worth chasing                #
##############################################################################
# The configuration is rooted at a Config.in with a tree of packages
# under it rather than at a Kconfig, which is what tells buildroot
# from kbuild.  It's here because buildroot is the one vendored build
# system that refuses to be told what this project cross-compiles
# with, and a rule about what goes in the file is worth stating
# against a build system that leaves something out of it.
cat >router/Config.in <<'EOF'
config BR2_BASE
	bool "base"
	default y

source "package/Config.in"
EOF

cat >router/package/Config.in <<'EOF'
source "package/busybox/Config.in"
EOF

cat >router/package/busybox/Config.in <<'EOF'
config BR2_PACKAGE_BUSYBOX
	bool "busybox"
	default y
EOF

cat >router/package/busybox/busybox.mk <<'EOF'
BUSYBOX_VERSION = 1.36.1
EOF

cat >router/configs/br_defconfig <<'EOF'
BR2_BASE=y
EOF

cat >router/Makefile <<'EOF'
O ?= $(CURDIR)/output

all: $(O)/.config
	@mkdir -p $(O)
	@cp $(O)/.config $(O)/images.txt

br_defconfig:
	@mkdir -p $(O)
	@cp $(CURDIR)/configs/br_defconfig $(O)/.config

include $(sort $(wildcard package/*/*.mk))
EOF

##############################################################################
# The file exists and says what was asked for                                #
##############################################################################
$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
cat obj/sub/configure-opts

# One raw CONFIGUREOPTS line per line, in the order they were
# written, and nothing else.  Taking them apart into whatever the
# build system made of them would lose the difference between two
# runs that were told the same things in a different order, and a
# later option is allowed to overwrite an earlier one.
#
# The last line is the one thing in here nobody wrote as a
# CONFIGUREOPTS: CROSS_COMPILE lands on the command line of every
# sub-make this writes, so a project that changed which machine it
# builds for has changed how the tree gets configured just as surely
# as a --make-var would have.  It's written even when it's empty,
# since "not cross-compiling" is an answer that can turn into a
# different one tomorrow.
cat >expected-opts <<'EOF'
--defconfig tiny_defconfig
--make-var MY_VAR=first
--env MY_ENV=one
CROSS_COMPILE=
EOF
diff expected-opts obj/sub/configure-opts

# It's written at configure time rather than at build time because
# make is what compares it against the last one, and make can't
# compare against a file that isn't there yet.  Everything else about
# the vendored tree is still make's to create: the output directory
# belongs to the tree, and the stamp says a build has happened.
test -f obj/sub/configure-opts
test ! -e obj/sub/build
test ! -e obj/sub/build-stamp

##############################################################################
# It is a prerequisite of the configuration and nothing else                 #
##############################################################################
# The configuration is what reads it, and the build already waits for
# the configuration -- so one file covers both, and there's no
# standing argument about which half of the state each new option
# belongs in when --env, --make-var and CROSS_COMPILE all land in
# both halves.
grep -q '^obj/sub/build/\.config:.* obj/sub/configure-opts' Makefile
if grep -q '^obj/sub/build-stamp:.*configure-opts' Makefile
then
    exit 1
fi

# Nothing in the Makefile knows how to build it, which is the point.
# A file make could rebuild is a file make would rebuild, and then
# the comparison this exists for would come out equal every time.
if grep -q '^obj/sub/configure-opts:' Makefile
then
    exit 1
fi

##############################################################################
# A no-op reconfigure does not touch it                                      #
##############################################################################
make $MAKE_ARGS
cat obj/sub/build/.config
cat obj/sub/build/built.txt
grep -q '^CONFIG_BASE=y$' obj/sub/build/.config
grep -q '^MY_VAR=first$' obj/sub/build/built.txt

# This is the half a naive fix gets wrong, and it's worth being loud
# about.  Writing the options out on every run is a line shorter and
# leaves the file newer than the .config every single time, which
# reconfigures and rebuilds every vendored tree -- an hour of
# somebody's day, for a buildroot -- on any run of pconfigure at all.
# The file is rewritten only when its contents change, so a run that
# was told exactly what the last one was told leaves the mtime where
# it found it.
#
# The sleep is what keeps this from being a statement about the
# filesystem's clock instead: a second write inside the same mtime
# tick looks identical to no write at all.
touch before-noop
sleep 2s
$PTEST_BINARY $PCONFIGURE_ARGS
diff expected-opts obj/sub/configure-opts
find obj/sub/configure-opts -newer before-noop > rewritten.txt
cat rewritten.txt
test ! -s rewritten.txt

# And make agrees, which is the part that actually costs something: a
# reconfigure that said nothing new leaves a built tree built.
make $MAKE_ARGS > noop.out
cat noop.out
if grep -q 'KCONFIG' noop.out
then
    exit 1
fi
if grep -q 'BUILDROOT' noop.out
then
    exit 1
fi
if grep -q 'MAKE' noop.out
then
    exit 1
fi

##############################################################################
# A changed CONFIGUREOPTS reconfigures and rebuilds                          #
##############################################################################
# The bug this whole file is about: every prerequisite these rules
# had was a file that belonged to the tree or to the project before
# pconfigure ran, and a recipe changing is not a reason for make to
# run a rule.  So a tree reconfigured with a different defconfig used
# to sit there configured the old way, underneath a Makefile that
# said otherwise, until somebody worked out that a distclean was the
# only thing that would move it.
#
# Both kinds of change are made at once because they leave by
# different doors: a defconfig is a make target the configuration
# rule asks for, and a --make-var is a variable on the command line
# of all three sub-makes.
touch before-change
sleep 2s
cat >Configfile <<'EOF'
BUILD_SYSTEMS += kconfig
BUILD_SYSTEMS += buildroot

SUBPROJECTS   += sub
CONFIGUREOPTS += --defconfig other_defconfig
CONFIGUREOPTS += --make-var MY_VAR=first
CONFIGUREOPTS += --make-var EXTRA_VAR=added
CONFIGUREOPTS += --env MY_ENV=one

SUBPROJECTS   += router
CONFIGUREOPTS += --defconfig br_defconfig
EOF
$PTEST_BINARY $PCONFIGURE_ARGS
cat obj/sub/configure-opts
grep -q '^--defconfig other_defconfig$' obj/sub/configure-opts
grep -q '^--make-var EXTRA_VAR=added$' obj/sub/configure-opts
find obj/sub/configure-opts -newer before-change > changed.txt
cat changed.txt
test -s changed.txt

make $MAKE_ARGS > changed.out
cat changed.out
grep -q 'KCONFIG' changed.out
grep -q 'MAKE' changed.out

# What the tree ended up with, rather than just the fact that make
# went in there.  The defconfig that ran is the new one, and what the
# old one wrote is gone rather than sitting underneath it: asserting
# on the output is the only way to tell a reconfigure from a rebuild
# that reused the .config it found lying around.
cat obj/sub/build/.config
cat obj/sub/build/built.txt
grep -q '^CONFIG_OTHER=y$' obj/sub/build/.config
if grep -q '^CONFIG_BASE=y$' obj/sub/build/.config
then
    exit 1
fi
grep -q '^EXTRA_VAR=added$' obj/sub/build/built.txt

##############################################################################
# CROSS_COMPILE counts                                                       #
##############################################################################
# It isn't a CONFIGUREOPTS and it was never written next to one, but
# it reaches the tree by exactly the same road -- a variable on the
# sub-make's command line -- so a project that changed which machine
# it builds for has to reconfigure the trees it vendors.  A tree
# configured for one machine and built for another is what this
# prevents, and that failure is a quiet one.
touch before-cross
sleep 2s
cat >Configfile <<'EOF'
BUILD_SYSTEMS += kconfig
BUILD_SYSTEMS += buildroot

CROSS_COMPILE  = faketc-

SUBPROJECTS   += sub
CONFIGUREOPTS += --defconfig other_defconfig
CONFIGUREOPTS += --make-var MY_VAR=first
CONFIGUREOPTS += --make-var EXTRA_VAR=added
CONFIGUREOPTS += --env MY_ENV=one

SUBPROJECTS   += router
CONFIGUREOPTS += --defconfig br_defconfig
EOF
$PTEST_BINARY $PCONFIGURE_ARGS
cat obj/sub/configure-opts
grep -q '^CROSS_COMPILE=faketc-$' obj/sub/configure-opts
find obj/sub/configure-opts -newer before-cross > crossed.txt
cat crossed.txt
test -s crossed.txt

make $MAKE_ARGS > crossed.out
cat crossed.out
grep -q 'KCONFIG' crossed.out
grep -q 'MAKE' crossed.out
cat obj/sub/build/built.txt
grep -q '^CROSS_COMPILE=faketc-$' obj/sub/build/built.txt

##############################################################################
# Buildroot does not get one                                                 #
##############################################################################
# Buildroot builds its own toolchain before it builds anything with
# it, so the prefix this project was configured with names a compiler
# that has nothing to do with the one buildroot is about to make --
# and buildroot's own manual says, in so many words, not to tell it
# this.  Nothing is on its sub-make's command line for it to be told
# with, so nothing about it belongs in its file either: a line no
# recipe reads would reconfigure a tree over a change that can't
# reach it.
cat obj/router/configure-opts
cat >expected-router <<'EOF'
--defconfig br_defconfig
EOF
diff expected-router obj/router/configure-opts
if grep -q 'CROSS_COMPILE' obj/router/configure-opts
then
    exit 1
fi

# Which is a statement about behaviour rather than about the contents
# of a file, so here it is as one: the project changes which machine
# it builds for, the kbuild tree is reconfigured over it, and the
# buildroot tree is left exactly where it was.  The sed is the whole
# edit -- nothing else in the Configfile moved.
touch before-cross-again
sleep 2s
sed 's/^CROSS_COMPILE  = faketc-$/CROSS_COMPILE  = othertc-/' Configfile > Configfile.new
mv Configfile.new Configfile
cat Configfile
grep -q '^CROSS_COMPILE  = othertc-$' Configfile
$PTEST_BINARY $PCONFIGURE_ARGS

find obj/sub/configure-opts -newer before-cross-again > sub-again.txt
find obj/router/configure-opts -newer before-cross-again > router-again.txt
cat sub-again.txt
cat router-again.txt
test -s sub-again.txt
test ! -s router-again.txt

make $MAKE_ARGS > cross-again.out
cat cross-again.out
grep -q 'KCONFIG' cross-again.out
if grep -q 'BUILDROOT' cross-again.out
then
    exit 1
fi
if grep -q 'MAKE.*router' cross-again.out
then
    exit 1
fi

##############################################################################
# Clean leaves it alone                                                      #
##############################################################################
# A clean throws away what was built, and this was never built: it's
# the record of what pconfigure said, and pconfigure isn't going to
# be run again before the next make.  A clean that took it would
# leave the configuration rule asking for a file nothing knows how to
# make, so the next build wouldn't fail to reconfigure -- it would
# fail outright, which is why what's checked here is the build rather
# than the file.
make $MAKE_ARGS clean
test -f obj/sub/configure-opts
test -f obj/router/configure-opts

if make $MAKE_ARGS > after-clean.out 2>&1
then
    cat after-clean.out
else
    cat after-clean.out
    exit 1
fi
if grep -q 'No rule to make target' after-clean.out
then
    exit 1
fi
test -f obj/sub/build-stamp
test -f obj/router/build-stamp

##############################################################################
# Distclean takes it                                                         #
##############################################################################
# Undoing a configure is the one case where this file has to go: what
# it holds is what the configure being undone decided, and the object
# directory it lives in is going with it.
make $MAKE_ARGS distclean
test ! -e obj/sub/configure-opts
test ! -e obj/router/configure-opts
test ! -e obj

# And neither vendored tree noticed any of this happening, which is
# the whole deal: their Makefiles are theirs.
grep -q '^O ?= ' sub/Makefile
grep -q '^O ?= ' router/Makefile
test ! -e sub/build
test ! -e router/output

##############################################################################
# A CROSS_COMPILE the shell would take apart                                 #
##############################################################################
# A CROSS_COMPILE is a prefix stuck on the front of a program name, so
# it is a path as often as it is a word: a toolchain lives wherever
# whoever unpacked it put it, and a directory with a space in its name
# is a thing that happens rather than a thing to be clever about.  It
# reaches a kbuild tree as a variable on its sub-make's command line,
# which is the one place the space matters -- unquoted, make is handed
# a CROSS_COMPILE worth the first word and a second word it reads as a
# target it was asked to build.
#
# Which is the same failure every --make-var beside it was quoted to
# avoid, and this is the line that used to be written the other way.
# Nothing above says anything about it: the CROSS_COMPILE the section
# further up uses is "faketc-", and a value with no space in it is
# spelled identically whether it was quoted or not.
mkdir -p $tempdir/spaced/tree/configs

cat >$tempdir/spaced/tree/Kconfig <<'EOF'
config BASE
	bool "base"
	default y
EOF

cat >$tempdir/spaced/tree/configs/tiny_defconfig <<'EOF'
CONFIG_BASE=y
EOF

# The tree writes back what it was handed, which is the only way to
# tell a CROSS_COMPILE that arrived whole from one that arrived as its
# first word -- and "$(MAKECMDGOALS)" is what says whether the rest of
# it turned into a goal.  The recipe that builds a kbuild tree names
# no target at all, on purpose: the tree's own first rule is what a
# build means, and a sub-make that was asked for a goal was asked by
# something that wasn't this Makefile.
cat >$tempdir/spaced/tree/Makefile <<'EOF'
O ?= $(CURDIR)/build

all: $(O)/.config
	@mkdir -p $(O)
	@cp $(O)/.config $(O)/built.txt
	@echo "CROSS_COMPILE=$(CROSS_COMPILE)" >> $(O)/built.txt
	@echo "GOALS=$(MAKECMDGOALS)" >> $(O)/built.txt

tiny_defconfig:
	@mkdir -p $(O)
	@cp $(CURDIR)/configs/tiny_defconfig $(O)/.config
EOF

cat >$tempdir/spaced/Configfile <<'EOF'
BUILD_SYSTEMS += kconfig

CROSS_COMPILE  = /opt/fake tools/bin/faketc-

SUBPROJECTS   += tree
CONFIGUREOPTS += --defconfig tiny_defconfig
EOF

cd $tempdir/spaced
$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# In the recipe first, because the two halves say different things:
# this is that the quoting was written, and the build below is that a
# shell then read it the way it was meant.  Quoted whole, name and
# all, which is what a variable on a make command line is -- an
# assignment in front of a command is the other shape and the other
# quoting, and this is not one.
grep -q "'CROSS_COMPILE=/opt/fake tools/bin/faketc-'" Makefile

make $MAKE_ARGS > spaced.out
cat spaced.out

# What the tree was actually handed, whole, rather than the first word
# of it.
cat obj/tree/build/built.txt
grep -q '^CROSS_COMPILE=/opt/fake tools/bin/faketc-$' obj/tree/build/built.txt

# And the sub-make was asked for nothing, which is what the recipe
# says and what the empty line here means.  This is the half that
# fails loudly rather than quietly: a "tools/bin/faketc-" that reached
# make as a goal of its own is a make that stops on a rule it hasn't
# got, so the assertion above would never be reached at all -- and
# this is what says which of the two went wrong when it does.
grep -q '^GOALS=$' obj/tree/build/built.txt

##############################################################################
# A path with a space in it, which make has no way to spell                  #
##############################################################################
# The section above is about a value, where the answer is quoting: a
# CROSS_COMPILE is text the recipe hands to a program, and a shell has
# a way to say "this is one argument".  A path is the other thing, and
# quoting is no answer to it at all.  What pconfigure does with a path
# is write it into a Makefile, and a target line, a prerequisite list
# and the argument of a make function are each read as a list of
# words: "$(abspath obj/my prefix)" is two absolute paths, so the tree
# gets told to install somewhere nobody named and every rule written
# under the prefix is two rules.  make has no quoting for a target
# name to fix that with, and by the time make has the line there is no
# record that the two words were ever one path.
#
# So the answer is a refusal, and it is written once --
# build_system::checked_project_path() -- for every path any vendored
# build system reads out of a CONFIGUREOPTS.  The two below are here
# to say "once": they are different build systems reading differently
# spelled options, one an install prefix and one a file that becomes a
# prerequisite, and what they print is the same sentence.
#
# It cannot be caught a level up, where "SUBPROJECTS += my sub" is
# caught, because a CONFIGUREOPTS is a command line: the spaces in one
# are what separate a flag from its value.  strict-lint.bash pins that
# from the other side, by asserting that a CONFIGUREOPTS with spaces
# in it draws no complaint at all.
mkdir -p $tempdir/spaced-prefix/tree
cd $tempdir/spaced-prefix

cat >tree/CMakeLists.txt <<'EOF'
project(tree)
EOF

cat >Configfile <<'EOF'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += tree
CONFIGUREOPTS += --prefix obj/my prefix
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS > spaced-prefix.out 2>&1
then
    exit 1
fi
cat spaced-prefix.out

grep -q "cmake: '--prefix obj/my prefix' has a space in it" spaced-prefix.out

# The diagnostic says what make would do with it rather than just
# saying no, and it says it in the words make would end up with --
# which is the thing nobody works out on their own from a build that
# failed two steps later.  The brackets are how the fake cmake in
# cmake.bash logs the same distinction, for the same reason: a list
# printed bare reads as the one thing it was meant to be.
grep -q 'reaches make as \[obj/my\] \[prefix\] rather than as one path' \
    spaced-prefix.out

# And it says what to write, which is the half a refusal is useless
# without.
grep -q "like '--prefix obj/toolchain'" spaced-prefix.out

# Nothing was written.  A refusal that left a Makefile behind would be
# the next "make" building against whatever the last configure
# decided, which is this failure wearing a different hat.
test ! -e Makefile

# The same question in a build system that shares nothing with cmake
# except the function that asks it, and about a path that isn't an
# install prefix: a --merge-config names a file that becomes a
# prerequisite of the configuration.  The file really is there and
# really is one file, which is what makes this a statement about what
# make can spell rather than about what exists.
mkdir -p $tempdir/spaced-frag/tree/configs $tempdir/spaced-frag/tree/scripts/kconfig
cd $tempdir/spaced-frag

cat >tree/Kconfig <<'EOF'
config BASE
	bool "base"
	default y
EOF

cat >tree/Makefile <<'EOF'
all:
	@true
EOF

cat >tree/scripts/kconfig/merge_config.sh <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x tree/scripts/kconfig/merge_config.sh

cat >"tree/configs/my frag.config" <<'EOF'
CONFIG_BASE=y
EOF

test -f "tree/configs/my frag.config"

cat >Configfile <<'EOF'
BUILD_SYSTEMS += kconfig

SUBPROJECTS   += tree
CONFIGUREOPTS += --defconfig tiny_defconfig
CONFIGUREOPTS += --merge-config tree/configs/my frag.config
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS > spaced-frag.out 2>&1
then
    exit 1
fi
cat spaced-frag.out

grep -q "kconfig: '--merge-config tree/configs/my frag.config' has a space in it" \
    spaced-frag.out
grep -q 'reaches make as \[tree/configs/my\] \[frag.config\] rather than as one path' \
    spaced-frag.out
test ! -e Makefile

# And the check is about the space rather than about the option, which
# is the half that would be a much worse bug the other way round: the
# same line with a name make can spell is taken, and the prefix lands
# in the recipe as the one path it names.
cd $tempdir/spaced-prefix

cat >Configfile <<'EOF'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += tree
CONFIGUREOPTS += --prefix obj/my-prefix
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
grep -q -- "-DCMAKE_INSTALL_PREFIX=\$(abspath obj/my-prefix)" Makefile

cd $tempdir

exit 0
