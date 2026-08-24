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
TESTDEPS           += obj/sub/build/arch/made-up/boot/Image
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

# Naming outputs adds no sub-makes at all.  There are two, and there
# were two before any of this: one writes the configuration and one
# builds the tree.  A rule per output that recursed would be a
# parallel make running the tree's own build system several times over
# in the same directory.
test "$(grep -c -- '$(MAKE) --no-print-directory -C sub ' Makefile)" = "2"

# What an output's rule does is check that the tree really produced it
# and settle its timestamp against the stamp.  Nothing else.
grep -A3 "^obj/sub/build/rootfs.cpio.gz: " Makefile > rule.out
cat rule.out
if grep -q "MAKE" rule.out
then
    exit 1
fi
grep -q "touch obj/sub/build/rootfs.cpio.gz" rule.out

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

# Changing a MAKEOPS reconfigures and rebuilds the tree, and the new
# value is what the tree gets.
sleep 2
sed -i.bak "s/EXTRA_NAME=an image/EXTRA_NAME=another image/" Configfile
rm -f Configfile.bak
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(cat obj/sub/build/arch/made-up/boot/Image)" = "another image"

exit 0
