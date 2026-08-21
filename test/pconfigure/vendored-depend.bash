#include "harness_start.bash"

# What make prints when it recurses into a vendored tree is separated
# by a tab, and the whole ordering argument down at the bottom is made
# out of grepping for those lines -- so the tab has to be a real one
# rather than something a grep pattern hopes is there.
tab="$(printf '\t')"

# Two trees that look like Linux from the outside and do as little as
# they possibly can on the inside: a Kconfig to be recognized by, a
# defconfig to start from, and a Makefile that leaves a file behind so
# a build can be seen to have happened.  Nothing in here says a word
# about pconfigure, because a vendored tree never does.
fake_tree()
{
    mkdir -p "$1/configs"

    cat >"$1/Kconfig" <<'EOF'
config BASE
	bool "base"
	default y
EOF

    cat >"$1/configs/tiny_defconfig" <<'EOF'
CONFIG_BASE=y
EOF

    cat >"$1/Makefile" <<'EOF'
O ?= $(CURDIR)/build

all: $(O)/.config
	@mkdir -p $(O)
	@cp $(O)/.config $(O)/built.txt

tiny_defconfig:
	@mkdir -p $(O)
	@cp $(CURDIR)/configs/tiny_defconfig $(O)/.config
EOF
}

fake_tree br
fake_tree linux
mkdir -p overlay

# A file that belongs to this project rather than to either tree: the
# thing a vendoring project actually has to say about how somebody
# else's tree gets configured.  Nothing in linux/ mentions it and
# nothing in linux/ could, which is the entire reason
# --depend-config exists.
cat >overlay/inittab <<'EOF'
::sysinit:/bin/true
EOF

# linux is written first on purpose.  Left to itself make builds what
# "all" names in the order "all" names it, so a run where br comes out
# first is a run where the --depend did something -- while a test that
# listed br first would pass no matter what this option did.  It also
# makes the --depend a forward reference, which resolves because every
# SUBPROJECTS in a project has been read before any of that project's
# targets are generated.
cat >Configfile <<EOF
BUILD_SYSTEMS += kconfig

SUBPROJECTS   += linux
CONFIGUREOPTS += --defconfig tiny_defconfig
CONFIGUREOPTS += --depend br
CONFIGUREOPTS += --depend-config overlay/inittab

SUBPROJECTS   += br
CONFIGUREOPTS += --defconfig tiny_defconfig
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

##############################################################################
# Configuring                                                                #
##############################################################################
# The two halves of what "--depend br" means.  Naming br's stamp says
# "wait until br has been built"; naming br's directory would say
# "wait until somebody writes a file in br", which is weaker than what
# was asked for and is already true of a tree nobody has built yet.  A
# directory is also a thing make is happy to call up to date the
# moment it exists, so getting this wrong doesn't fail loudly -- it
# just builds the two trees in whatever order it feels like.
grep -q "^obj/kconfig/linux/build-stamp:.* obj/kconfig/br/build-stamp" Makefile
if grep -q "^obj/kconfig/linux/build-stamp:.* br/$" Makefile
then
    exit 1
fi
if grep -q "^obj/kconfig/linux/build-stamp:.* br$" Makefile
then
    exit 1
fi
if grep -q "^obj/kconfig/linux/build-stamp:.* br " Makefile
then
    exit 1
fi

# The edge only points one way.  br was told nothing about linux, so
# nothing about linux may show up in br's rules: an extra edge here
# would be a loop, and make has nothing useful to say about one of
# those.
if grep -q "^obj/kconfig/br/build-stamp:.* linux" Makefile
then
    exit 1
fi
if grep -q "^obj/kconfig/br/build/.config:.* overlay/inittab" Makefile
then
    exit 1
fi

# A --depend-config lands on the configuration rather than on the
# build, since a file that decides what the tree is configured to be
# has to be read before the configuration is worked out and not after
# it.  It reaches the build anyway, because the stamp already waits
# for the .config -- so the second grep here is the first one's other
# half, and the two together are why --depend-config doesn't also have
# to be written as a --depend.
grep -q "^obj/kconfig/linux/build/.config:.* overlay/inittab" Makefile
grep -q "^obj/kconfig/linux/build-stamp: obj/kconfig/linux/build/.config" Makefile

# Both trees are still built by default: waiting for br is an ordering
# constraint on linux, not a statement that br is only worth building
# because linux needs it.
grep -q "^all: obj/kconfig/linux/build-stamp$" Makefile
grep -q "^all: obj/kconfig/br/build-stamp$" Makefile

##############################################################################
# Building                                                                   #
##############################################################################
make $MAKE_ARGS > first.out
cat first.out

# What all of the above was for.  make was handed linux first and
# built br first anyway, which is the ordering that nothing in either
# tree could have told it about.
grep -q "MAKE${tab}br" first.out
grep -q "MAKE${tab}linux" first.out
grep -n "MAKE${tab}br" first.out | cut -d: -f1 > br.at
grep -n "MAKE${tab}linux" first.out | cut -d: -f1 > linux.at
test "$(cat br.at)" -lt "$(cat linux.at)"

test -f obj/kconfig/br/build/built.txt
test -f obj/kconfig/linux/build/built.txt
test -f obj/kconfig/br/build-stamp
test -f obj/kconfig/linux/build-stamp

# An edge between two trees isn't a reason to recurse into either of
# them a second time: br's stamp got older than nothing, so linux's
# stamp is still up to date.
make $MAKE_ARGS > second.out
if grep -q "MAKE" second.out
then
    exit 1
fi

##############################################################################
# Rebuilding                                                                 #
##############################################################################
# Touching the overlay redoes the configuration of the tree that named
# it, and then that tree's build.  This is the half of --depend-config
# a person actually notices: an inittab this project wrote is a file
# the vendored tree reads without ever having heard of it.
sleep 2s
touch overlay/inittab
make $MAKE_ARGS > third.out
cat third.out
grep -q "KCONFIG${tab}linux" third.out
grep -q "MAKE${tab}linux" third.out

# ... and it says nothing at all about br, which was never told about
# the overlay and has no business being reconfigured because of it.  A
# --depend-config that landed on every vendored tree rather than on
# the one whose CONFIGUREOPTS it followed would rebuild the world
# here, and would look like it was working while it did.
if grep -q "KCONFIG${tab}br" third.out
then
    exit 1
fi
if grep -q "MAKE${tab}br" third.out
then
    exit 1
fi

##############################################################################
# Paths that don't name anything worth waiting for                           #
##############################################################################
# Each of these is its own project in its own directory, run in a
# subshell whose failure is the assertion -- this test has "set -e"
# on, so a pconfigure that aborts anywhere else takes the whole run
# with it.  What's checked is what was said and not merely that
# something was: every one of these is a person who wrote a path down,
# and they need to be told which of the several available ways to be
# wrong they picked.

# A pconfigure subproject is read into this run rather than built by
# it, so there is no one file that says it finished -- it's a pile of
# binaries and libraries, any of which might be the one that was
# meant.  The advice is to name that file, since only whoever wrote
# the --depend knows which of them it is.
mkdir -p bad-psub/psub/src
fake_tree bad-psub/linux

cat >bad-psub/psub/Configfile <<'EOF'
LANGUAGES += c

LIBRARIES += libpsub.so
SOURCES   += psub.c
EOF

cat >bad-psub/psub/src/psub.c <<'EOF'
int psub(void) { return 3; }
EOF

cat >bad-psub/Configfile <<'EOF'
BUILD_SYSTEMS += kconfig

SUBPROJECTS   += psub

SUBPROJECTS   += linux
CONFIGUREOPTS += --defconfig tiny_defconfig
CONFIGUREOPTS += --depend psub
EOF

if (cd bad-psub && $PTEST_BINARY $PCONFIGURE_ARGS) > bad-psub.out 2>&1
then
    exit 1
fi
cat bad-psub.out
grep -q "'--depend psub' names 'psub/', which isn't a vendored subproject" \
    bad-psub.out
grep -q "a pconfigure subproject has no one file that says it's been built" \
    bad-psub.out
grep -q "so name the file you actually need instead" bad-psub.out

# A path that names nothing at all is a typo, and the only thing to do
# with one is say so while there's still somebody around who knows
# what was meant.  Passed through it would become a prerequisite make
# has no rule for, and the complaint would arrive later, from make,
# about a file nobody wrote in a Makefile nobody edited.
mkdir -p bad-missing
fake_tree bad-missing/linux

cat >bad-missing/Configfile <<'EOF'
BUILD_SYSTEMS += kconfig

SUBPROJECTS   += linux
CONFIGUREOPTS += --defconfig tiny_defconfig
CONFIGUREOPTS += --depend nothing/here
EOF

if (cd bad-missing && $PTEST_BINARY $PCONFIGURE_ARGS) > bad-missing.out 2>&1
then
    exit 1
fi
cat bad-missing.out
grep -q "'--depend nothing/here' names 'nothing/here', which is neither a file nor a vendored subproject" \
    bad-missing.out

# A tree that waits for itself is a rule that is its own prerequisite,
# which make deals with by dropping the edge and mentioning it in
# passing.  It's always a mistake and it's always somebody who meant a
# different tree, so it's worth rather more than a mention.
mkdir -p bad-self
fake_tree bad-self/linux

cat >bad-self/Configfile <<'EOF'
BUILD_SYSTEMS += kconfig

SUBPROJECTS   += linux
CONFIGUREOPTS += --defconfig tiny_defconfig
CONFIGUREOPTS += --depend linux
EOF

if (cd bad-self && $PTEST_BINARY $PCONFIGURE_ARGS) > bad-self.out 2>&1
then
    exit 1
fi
cat bad-self.out
grep -q "'--depend linux' names this subproject" bad-self.out

exit 0
