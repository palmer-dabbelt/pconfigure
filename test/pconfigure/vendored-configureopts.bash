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

exit 0
