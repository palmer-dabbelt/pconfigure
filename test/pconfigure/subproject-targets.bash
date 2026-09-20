#include "harness_start.bash"

top="$tempdir"

mkdir -p sub/configs test/integration

# A vendored tree that names what it builds, so that the rest of the
# build can wait for the file rather than for the tree.
cat >Configfile <<EOF
BUILD_SYSTEMS      += kconfig

SUBPROJECTS        += sub
CONFIGUREOPTS      += --defconfig tiny_defconfig
MAKEOPS            += ARCH=made-up
MAKEOPS            += EXTRA_NAME=an image
SUBPROJECT_TARGETS += arch/made-up/boot/Image
SUBPROJECT_TARGETS += rootfs.cpio.gz

LANGUAGES          += bash

PHONY              += integration
TESTDEPS           += sub/build/arch/made-up/boot/Image
TESTDEPS           += obj/sub/build/rootfs.cpio.gz
TESTSRC            += boots.bash
EOF

cat >sub/Kconfig <<'EOF'
config BASE
	bool "base"
	default y
EOF

cat >sub/configs/tiny_defconfig <<'EOF'
CONFIG_BASE=y
EOF

# A tree that puts what it builds where it was told to, and that
# writes down what it was told so the test can check it got there.
cat >sub/Makefile <<'EOF'
O ?= $(CURDIR)/build
ARCH ?= unset
EXTRA_NAME ?= unset

all: $(O)/.config
	@mkdir -p $(O)/arch/$(ARCH)/boot
	@echo "$(EXTRA_NAME)" > $(O)/arch/$(ARCH)/boot/Image
	@echo rootfs > $(O)/rootfs.cpio.gz

tiny_defconfig:
	@mkdir -p $(O)
	@cp $(CURDIR)/configs/tiny_defconfig $(O)/.config
EOF

cat >test/integration/boots.bash <<EOF
set -e

# Both named outputs were built before this ran, which is what the
# TESTDEPS asked for -- and neither of them is a file that any rule
# other than the vendored tree's own build ever wrote.
test -f obj/sub/build/arch/made-up/boot/Image
test -f obj/sub/build/rootfs.cpio.gz

# The MAKEOPS reached the tree, both of them, and the one with a space
# in its value arrived with the space still in it.
test "\$(cat obj/sub/build/arch/made-up/boot/Image)" = "an image"

exit 0
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# Both variables are on the sub-make's command line, in the order they
# were written.  Each is one argument however many spaces are in its
# value: unquoted, "EXTRA_NAME=an image" hands make a variable worth
# "an" and then a goal called "image", which is not a target and stops
# the build.
grep -q -- "-C sub .*'ARCH=made-up' 'EXTRA_NAME=an image'" Makefile

# Each named output is a target of its own, and every one of them
# waits on the one stamp that says the tree has been built.  That is
# what keeps a parallel make that wants both of them from starting two
# sub-makes in the same tree.
grep -q "^obj/sub/build/arch/made-up/boot/Image: obj/sub/build-stamp$" Makefile
grep -q "^obj/sub/build/rootfs.cpio.gz: obj/sub/build-stamp$" Makefile

# The two TESTDEPS above name one of those each, and they're spelled
# differently on purpose: the first from the object directory the tree
# builds into, the second from the project.  Both are the same file
# and both come out as the path the rule that builds it is written
# under, which is the only spelling the rest of the Makefile knows.
grep -q "^check/integration/boots.bash:.* obj/sub/build/arch/made-up/boot/Image" Makefile
grep -q "^check/integration/boots.bash:.* obj/sub/build/rootfs.cpio.gz" Makefile

# Naming a tree's output from the object directory is not the same as
# naming a directory of the project's own: only a file the tree was
# said to produce is read that way, so nothing that used to mean a
# path in the project has started meaning something else.
if grep -q "^check/integration/boots.bash:.* sub/build/" Makefile
then
    exit 1
fi

# Naming outputs adds no sub-makes at all.  There are two, and there
# were two before any of this: one writes the configuration and one
# builds the tree.  A rule per output that recursed would be a
# parallel make running the tree's own build system several times over
# in the same directory.
test "$(grep -c -- '$(MAKE) --no-print-directory -C sub ' Makefile)" = "2"

# What an output's rule does is check that the tree really produced it
# and settle its timestamp against the stamp.  Nothing else.
#
# The path is quoted where the recipe runs it, which is why the touch
# is asserted with the quotes on: the recipe is a line of shell, and
# the one thing a SUBPROJECT_TARGETS is guaranteed to be is text
# somebody wrote.  What that buys is further down, where a path with a
# quote in it is named on purpose.
grep -A3 "^obj/sub/build/rootfs.cpio.gz: " Makefile > rule.out
cat rule.out
if grep -q "MAKE" rule.out
then
    exit 1
fi
grep -q "touch 'obj/sub/build/rootfs.cpio.gz'" rule.out

# The options this run gave are written down for make to compare
# against, and a MAKEOPS is part of that: changing one changes how the
# tree gets built.
grep -q "^MAKEOPS ARCH=made-up$" obj/sub/configure-opts

make $MAKE_ARGS
test -f obj/sub/build/arch/made-up/boot/Image
test -f obj/sub/build/rootfs.cpio.gz

# Asking for a named output on its own works, and does not run the
# tree again now that it is built.
make $MAKE_ARGS obj/sub/build/rootfs.cpio.gz > second.out 2>&1
cat second.out
if grep -q "MAKE	sub" second.out
then
    exit 1
fi

# Nothing is left permanently out of date: a second make from the top
# has nothing to do.  Without settling the stamp against the outputs
# this rebuilds the world on every single make.
make $MAKE_ARGS > again.out 2>&1
cat again.out
if grep -q "MAKE	sub" again.out
then
    exit 1
fi

make $MAKE_ARGS check
ptest --verbose
test -f check/integration/boots.bash

# A SUBPROJECT_TARGETS that names a file the tree doesn't build is a
# mistake in the Configfile, and the build says so rather than letting
# whatever wanted the file run without it.  A plain "make" is what
# asks, so the complaint arrives at the first build rather than
# whenever something happens to want that file.
mkdir -p $top/wrong/sub/configs
cd $top/wrong

cat >Configfile <<EOF
BUILD_SYSTEMS      += kconfig

SUBPROJECTS        += sub
CONFIGUREOPTS      += --defconfig tiny_defconfig
SUBPROJECT_TARGETS += never-built
EOF

cat >sub/Kconfig <<EOF
config BASE
	bool "base"
	default y
EOF

cat >sub/configs/tiny_defconfig <<EOF
CONFIG_BASE=y
EOF

cat >sub/Makefile <<'EOF'
O ?= $(CURDIR)/build

all: $(O)/.config
	@mkdir -p $(O)
	@echo something-else > $(O)/other

tiny_defconfig:
	@mkdir -p $(O)
	@cp $(CURDIR)/configs/tiny_defconfig $(O)/.config
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
if make $MAKE_ARGS > wrong.out 2>&1
then
    exit 1
fi
cat wrong.out
grep -q "'never-built' is not in 'obj/sub/build'" wrong.out
grep -q "SUBPROJECT_TARGETS names a file the tree builds" wrong.out

cd $top

##############################################################################
# And a name with a quote in it, which is the same complaint said about a
# harder file.  A SUBPROJECT_TARGETS is text somebody wrote, and the
# recipe that checks for the file is a line of shell: an apostrophe in
# a name -- which is a thing filenames have -- opens a quoted string in
# the "test" that decides whether to complain at all, and a double
# quote closes the one the complaint used to be written with.  Either
# way what a build printed was the shell giving up on a line whose
# entire job was to say which file the tree didn't build.
#
# Both characters are here because they break different halves.  The
# apostrophe is the one the old spelling survived in the message and
# died on in the "test"; the double quote is the one it survived in
# the "test" and died on in the message.  A fix to one of the two
# halves passes a test that names only the other.
mkdir -p $top/quoted/sub/configs
cd $top/quoted

cat >Configfile <<EOF
BUILD_SYSTEMS      += kconfig

SUBPROJECTS        += sub
CONFIGUREOPTS      += --defconfig tiny_defconfig
SUBPROJECT_TARGETS += it's.txt
SUBPROJECT_TARGETS += say"what
EOF

cat >sub/Kconfig <<EOF
config BASE
	bool "base"
	default y
EOF

cat >sub/configs/tiny_defconfig <<EOF
CONFIG_BASE=y
EOF

# The tree builds one of the two, so that both arms are taken: the
# file that is there has to survive the recipe that checks for it, and
# the file that isn't has to be complained about by name.
cat >sub/Makefile <<'EOF'
O ?= $(CURDIR)/build

all: $(O)/.config
	@mkdir -p $(O)
	@echo built > "$(O)/it's.txt"

tiny_defconfig:
	@mkdir -p $(O)
	@cp $(CURDIR)/configs/tiny_defconfig $(O)/.config
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

if make $MAKE_ARGS > quoted.out 2>&1
then
    exit 1
fi
cat quoted.out

# The complaint is the complaint, naming the file the tree didn't
# build, rather than the shell reporting that it could not read the
# line the complaint was on.
grep -q "'say\"what' is not in 'obj/sub/build'" quoted.out
grep -q "SUBPROJECT_TARGETS names a file the tree builds" quoted.out

# Said here as well as above because the two are what tell a fix from
# a coincidence: a recipe the shell gave up on stops the build too, so
# "make failed" on its own says nothing at all.
if grep -qi "unexpected EOF" quoted.out
then
    exit 1
fi
if grep -qi "syntax error" quoted.out
then
    exit 1
fi

# And the file that was built came through its own rule intact, which
# is the other arm: an apostrophe in the name breaks the "test" that
# looks for it before it ever reaches a message.
if grep -q "it's.txt' is not in" quoted.out
then
    exit 1
fi
test -f "obj/sub/build/it's.txt"

cd $top

# One vendored tree can wait for a file another one builds, rather
# than for the whole of it.  That file doesn't exist on a fresh
# checkout, which is the difference between naming it and naming any
# other file: it has a rule behind it now.
mkdir -p $top/depend/one/configs $top/depend/two/configs
cd $top/depend

cat >Configfile <<EOF
BUILD_SYSTEMS      += kconfig

SUBPROJECTS        += one
CONFIGUREOPTS      += --defconfig tiny_defconfig
SUBPROJECT_TARGETS += toolchain

SUBPROJECTS        += two
CONFIGUREOPTS      += --defconfig tiny_defconfig
CONFIGUREOPTS      += --depend obj/one/build/toolchain
EOF

for d in one two
do
    cat >$d/Kconfig <<EOF
config BASE
	bool "base"
	default y
EOF
    cat >$d/configs/tiny_defconfig <<EOF
CONFIG_BASE=y
EOF
    cat >$d/Makefile <<'EOF'
O ?= $(CURDIR)/build

all: $(O)/.config
	@mkdir -p $(O)
	@echo built > $(O)/toolchain

tiny_defconfig:
	@mkdir -p $(O)
	@cp $(CURDIR)/configs/tiny_defconfig $(O)/.config
EOF
done

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# The second tree waits for the first tree's named output rather than
# for the first tree's stamp, which is the finer-grained edge that
# naming it is for.
grep -q "^obj/two/build-stamp:.*obj/one/build/toolchain" Makefile

make $MAKE_ARGS
test -f obj/one/build/toolchain
test -f obj/two/build-stamp

cd $top

# A TESTDEPS is resolved where it's written, so one written above the
# SUBPROJECT_TARGETS that would have claimed it means the other thing:
# a path in the project, which nothing builds.  Reading the file in a
# different order is the whole fix, and neither line says on its own
# that it's the one in the wrong place.
mkdir -p $top/order/sub/configs $top/order/test/integration
cd $top/order

cat >Configfile <<EOF
BUILD_SYSTEMS      += kconfig

SUBPROJECTS        += sub
CONFIGUREOPTS      += --defconfig tiny_defconfig

LANGUAGES          += bash

PHONY              += integration
TESTDEPS           += sub/build/rootfs.cpio.gz
TESTSRC            += boots.bash

SUBPROJECT_TARGETS += rootfs.cpio.gz
EOF

cat >sub/Kconfig <<EOF
config BASE
	bool "base"
	default y
EOF

cat >sub/configs/tiny_defconfig <<EOF
CONFIG_BASE=y
EOF

cat >sub/Makefile <<'EOF'
O ?= $(CURDIR)/build

all: $(O)/.config
	@mkdir -p $(O)
	@echo rootfs > $(O)/rootfs.cpio.gz

tiny_defconfig:
	@mkdir -p $(O)
	@cp $(CURDIR)/configs/tiny_defconfig $(O)/.config
EOF

cat >test/integration/boots.bash <<'EOF'
true
EOF

# The subshell is the assertion: "set -e" is on, so a command expected
# to fail has to be somewhere a failure isn't fatal.
if $PTEST_BINARY $PCONFIGURE_ARGS > order.out 2>&1
then
    exit 1
fi
cat order.out

# It names both lines, since which of the two moves is the reader's
# choice and neither one is wrong by itself.
grep -q "Configfile:9" order.out
grep -q "SUBPROJECT_TARGETS += rootfs.cpio.gz" order.out

# ... and says what the TESTDEPS ended up meaning instead, which is
# the part that would otherwise only show up as make refusing to build
# a file nobody ever wrote a rule for.
grep -q "obj/sub/build/rootfs.cpio.gz" order.out
grep -q "above the tests that wait for them" order.out

# It stopped before writing anything, rather than leaving a
# half-configured tree behind for the next command to trip over.
test ! -e Makefile

cd $top

# Changing a MAKEOPS reconfigures and rebuilds the tree, and the new
# value is what the tree gets.
sleep 2
sed -i.bak "s/EXTRA_NAME=an image/EXTRA_NAME=another image/" Configfile
rm -f Configfile.bak
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(cat obj/sub/build/arch/made-up/boot/Image)" = "another image"

cd $top

##############################################################################
# A tree vendored by a subproject, built from both ends                      #
##############################################################################
# A subproject's Makefile is written to be included by its parent's and
# to work on its own, so every path in it is spelled through a variable
# that is the subproject's directory from above and nothing from
# inside.  The rule an output gets is a line of shell with the path in
# it three times over -- the test that looks for the file, the message
# that names it, and the touch that settles its timestamp -- and all
# three of them are quoted, which is the shape that could have stopped
# the rewriting from finding them.  It doesn't: a quote is one of the
# characters a path is allowed to start after.
#
# Nothing else here says that.  Every other project in this file is one
# project deep, where the variable is empty and a rule that leaned on
# it and a rule that ignored it are the same rule.
mkdir -p $top/nested/child/vend/configs
cd $top/nested

cat >Configfile <<EOF
SUBPROJECTS += child
EOF

cat >child/Configfile <<EOF
BUILD_SYSTEMS      += kconfig

SUBPROJECTS        += vend
CONFIGUREOPTS      += --defconfig tiny_defconfig
SUBPROJECT_TARGETS += made
EOF

cat >child/vend/Kconfig <<EOF
config BASE
	bool "base"
	default y
EOF

cat >child/vend/configs/tiny_defconfig <<EOF
CONFIG_BASE=y
EOF

cat >child/vend/Makefile <<'EOF'
O ?= $(CURDIR)/build

all: $(O)/.config
	@mkdir -p $(O)
	@echo made > $(O)/made

tiny_defconfig:
	@mkdir -p $(O)
	@cp $(CURDIR)/configs/tiny_defconfig $(O)/.config
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile child/obj/Makefile.child

# The subproject really is included rather than recursed into, which is
# what puts the variable in front of every path in the rule below --
# without it there would be nothing here to get wrong.
grep -q "^include \$(pconfigure_subdir_child)obj/Makefile.child\$" Makefile

# And it is in front of the paths in the recipe, quotes and all.
grep -A3 "obj/vend/build/made: " child/obj/Makefile.child > nested-rule.out
cat nested-rule.out
grep -q "test -e '\$(pconfigure_subdir_child)obj/vend/build/made'" nested-rule.out
grep -q "touch '\$(pconfigure_subdir_child)obj/vend/build/made'" nested-rule.out

# Built from the top, which is the spelling the parent's Makefile is
# for.
make $MAKE_ARGS > nested.out
cat nested.out
test "$(cat child/obj/vend/build/made)" = "made"

# And from inside the subproject, which is the other half of what that
# Makefile promises: the variable defaults to nothing down here, so a
# recipe that leaned on it says something else.  The file is taken away
# first, because a rule that named the wrong path would otherwise be
# satisfied by the build above having already made the right one.
rm -rf child/obj/vend/build
(cd child && make $MAKE_ARGS -f obj/Makefile.child) > nested-inside.out 2>&1
cat nested-inside.out
test "$(cat child/obj/vend/build/made)" = "made"

cd $top

exit 0
