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

mkdir -p src sub/configs sub/drivers sub/hidden

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

# The vendored build system, which writes down what it read the way
# kbuild does: an assignment, one path a line, a backslash on the end.
cat >sub/Makefile <<'EOF'
O ?= $(CURDIR)/build

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
# What the Makefile says before anything has been built                      #
##############################################################################
# The fragment is included, and it is a file this Makefile knows how
# to build -- which is what lets make bring it into existence rather
# than stopping on it.
grep -q "^include obj/sub/config-deps.mk$" Makefile
grep -q "^obj/sub/config-deps.mk: obj/sub/config-deps-context$" Makefile

# Its only prerequisite is a file pconfigure wrote and nothing in this
# Makefile builds.  That is what makes the remaking terminate: it can
# go out of date at most once per configure.
test -e obj/sub/config-deps-context

# And the guess has not got the hidden one, which is the point.
if grep "^obj/sub/build/.config:" Makefile | grep -q "hidden"
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
