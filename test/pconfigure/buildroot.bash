#include "harness_start.bash"

mkdir -p src
mkdir -p sub/configs sub/utils sub/package/busybox sub/package/dropbear
mkdir -p sub/support/misc sub/linux sub/fs/ext2
mkdir -p ext/package/mine

# Buildroot is pulled in the same way any other subproject is, and
# nothing inside it says a word about pconfigure: BUILD_SYSTEMS says
# buildroot is available, and which subproject gets built that way is
# worked out from what's in the directory.
cat >Configfile <<EOF
BUILD_SYSTEMS += buildroot

SUBPROJECTS   += sub
CONFIGUREOPTS += --defconfig tiny_defconfig
CONFIGUREOPTS += --configure BR2_PACKAGE_DROPBEAR=y
CONFIGUREOPTS += --configure BR2_TARGET_GENERIC_HOSTNAME="my router"
CONFIGUREOPTS += --external ext

LANGUAGES   += c
BINARIES    += test
SOURCES     += test.c
EOF

cat >src/test.c <<EOF
int main(void) { return 0; }
EOF

##############################################################################
# A tree that looks enough like buildroot to be worth chasing                #
##############################################################################
# The configuration is rooted at a Config.in rather than a Kconfig,
# which is the thing that tells buildroot from kbuild.
cat >sub/Config.in <<'EOF'
config BR2_BASE
	bool "base"
	default y

source "package/Config.in"
source "fs/Config.in"
EOF

cat >sub/Config.in.legacy <<'EOF'
config BR2_LEGACY
	bool "legacy"
EOF

cat >sub/package/Config.in <<'EOF'
source "package/busybox/Config.in"
source "package/dropbear/Config.in"
EOF

cat >sub/package/busybox/Config.in <<'EOF'
config BR2_PACKAGE_BUSYBOX
	bool "busybox"
	default y
EOF

cat >sub/package/dropbear/Config.in <<'EOF'
config BR2_PACKAGE_DROPBEAR
	bool "dropbear"
EOF

cat >sub/fs/Config.in <<'EOF'
config BR2_TARGET_ROOTFS_EXT2
	bool "ext2"
EOF

cat >sub/configs/tiny_defconfig <<'EOF'
BR2_BASE=y
BR2_PACKAGE_BUSYBOX=y
EOF

# The build description is a pile of per-package .mk files that the
# top-level Makefile pulls in all at once, which is the other thing
# buildroot does that kbuild doesn't.
cat >sub/Makefile <<'EOF'
O ?= $(CURDIR)/output

all: $(O)/.config
	@mkdir -p $(O)
	@cp $(O)/.config $(O)/images.txt

tiny_defconfig:
	@mkdir -p $(O)
	@cp $(CURDIR)/configs/tiny_defconfig $(O)/.config

olddefconfig:
	@mkdir -p $(O)
	@echo "# olddefconfig" >> $(O)/.config

include support/misc/utils.mk
include $(sort $(wildcard package/*/*.mk))
include $(sort $(wildcard fs/*/*.mk))
include $(sort $(wildcard linux/*.mk))
EOF

cat >sub/support/misc/utils.mk <<'EOF'
BR2_UTIL = yes
EOF

cat >sub/package/busybox/busybox.mk <<'EOF'
BUSYBOX_VERSION = 1.36.1
EOF

cat >sub/package/dropbear/dropbear.mk <<'EOF'
DROPBEAR_VERSION = 2022.83
EOF

cat >sub/fs/ext2/ext2.mk <<'EOF'
EXT2_SIZE = 60M
EOF

cat >sub/linux/linux.mk <<'EOF'
LINUX_VERSION = 6.6
EOF

# Buildroot's .config editor lives somewhere else and is spelled
# something else, but does the same job.
cat >sub/utils/config <<'EOF'
#!/bin/bash
set -e
file=.config
while [[ "$#" -gt 0 ]]
do
    case "$1" in
    --file)     file="$2";                         shift 2;;
    --enable)   echo "$2=y" >> "$file";            shift 2;;
    --module)   echo "$2=m" >> "$file";            shift 2;;
    --disable)  echo "# $2 is not set" >> "$file"; shift 2;;
    --set-val)  echo "$2=$3" >> "$file";           shift 3;;
    --set-str)  echo "$2=\"$3\"" >> "$file";       shift 3;;
    *)                                             shift 1;;
    esac
done
EOF
chmod +x sub/utils/config

##############################################################################
# A BR2_EXTERNAL tree, which is this project's own and not vendored          #
##############################################################################
cat >ext/external.desc <<'EOF'
name: MINE
desc: packages of my own
EOF

cat >ext/Config.in <<'EOF'
source "$BR2_EXTERNAL_MINE_PATH/package/mine/Config.in"
EOF

cat >ext/external.mk <<'EOF'
include $(sort $(wildcard $(BR2_EXTERNAL_MINE_PATH)/package/*/*.mk))
EOF

cat >ext/package/mine/Config.in <<'EOF'
config BR2_PACKAGE_MINE
	bool "mine"
EOF

cat >ext/package/mine/mine.mk <<'EOF'
MINE_VERSION = 1.0
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# Nothing at all was written inside the vendored tree.  Its Makefile
# in particular is the file its build system reads, and writing one
# over it would destroy the thing we were asked to build.
grep -q "^O ?= " sub/Makefile
test ! -e sub/obj
test ! -e sub/Configfile
test ! -e ext/Makefile

# The rules that drive it live in the Makefile of whoever pulled it
# in, since there's nowhere else for them to go.
grep -q "^obj/buildroot/sub/build/.config:" Makefile
grep -q "^obj/buildroot/sub/build-stamp:" Makefile
grep -q "^all: obj/buildroot/sub/build-stamp$" Makefile
if grep -q "include sub/Makefile" Makefile
then
    exit 1
fi

# A tree with a Config.in in it isn't a kbuild tree, so the kconfig
# build system doesn't get a chance to claim it -- and it wasn't even
# asked for here.
if grep -q "obj/kconfig" Makefile
then
    exit 1
fi

# The whole configuration was chased, out of Config.in rather than out
# of a Kconfig.
grep -q "^obj/buildroot/sub/build/.config:.* sub/Config.in" Makefile
grep -q "^obj/buildroot/sub/build/.config:.* sub/Config.in.legacy" Makefile
grep -q "^obj/buildroot/sub/build/.config:.* sub/package/Config.in" Makefile
grep -q "^obj/buildroot/sub/build/.config:.* sub/package/busybox/Config.in" Makefile
grep -q "^obj/buildroot/sub/build/.config:.* sub/package/dropbear/Config.in" Makefile
grep -q "^obj/buildroot/sub/build/.config:.* sub/fs/Config.in" Makefile
grep -q "^obj/buildroot/sub/build/.config:.* sub/configs/tiny_defconfig" Makefile

# So was the build description, which a buildroot tree includes by
# wildcard rather than by naming one file at a time.  A package that
# isn't even enabled is still a file this configuration might read
# tomorrow.
grep -q "^obj/buildroot/sub/build-stamp:.* sub/Makefile" Makefile
grep -q "^obj/buildroot/sub/build-stamp:.* sub/support/misc/utils.mk" Makefile
grep -q "^obj/buildroot/sub/build-stamp:.* sub/package/busybox/busybox.mk" Makefile
grep -q "^obj/buildroot/sub/build-stamp:.* sub/package/dropbear/dropbear.mk" Makefile
grep -q "^obj/buildroot/sub/build-stamp:.* sub/fs/ext2/ext2.mk" Makefile
grep -q "^obj/buildroot/sub/build-stamp:.* sub/linux/linux.mk" Makefile

# An external tree is reached through a variable that names it, so
# nothing in the vendored tree points at it: what it holds is named
# because BR2_EXTERNAL says what such a tree is made of.
grep -q "BR2_EXTERNAL=" Makefile
grep -q "^obj/buildroot/sub/build/.config:.* ext/Config.in" Makefile
grep -q "^obj/buildroot/sub/build/.config:.* ext/package/mine/Config.in" Makefile
grep -q "^obj/buildroot/sub/build-stamp:.* ext/external.desc" Makefile
grep -q "^obj/buildroot/sub/build-stamp:.* ext/external.mk" Makefile
grep -q "^obj/buildroot/sub/build-stamp:.* ext/package/mine/mine.mk" Makefile

##############################################################################
# Building                                                                   #
##############################################################################
make $MAKE_ARGS

# The defconfig was applied, and then the options on top of it.
grep -q "^BR2_BASE=y$" obj/buildroot/sub/build/.config
grep -q "^BR2_PACKAGE_BUSYBOX=y$" obj/buildroot/sub/build/.config
grep -q "^BR2_PACKAGE_DROPBEAR=y$" obj/buildroot/sub/build/.config
grep -q "^# olddefconfig$" obj/buildroot/sub/build/.config

# A value that was written with quotes around it is a string, and a
# string keeps its quotes in a .config -- which is the tree's own
# program's job, and the reason it gets told which kind this is.
grep -q '^BR2_TARGET_GENERIC_HOSTNAME="my router"$' obj/buildroot/sub/build/.config

test -f obj/buildroot/sub/build/images.txt
test -f obj/buildroot/sub/build-stamp
test ! -e sub/output

# A second make in a tree that's already built doesn't recurse at all,
# which is the whole point of chasing those dependencies.
make $MAKE_ARGS > second.out
if grep -q "MAKE" second.out
then
    exit 1
fi

# Touching a package's .mk gets us back into buildroot's own make, and
# that one didn't need the configuration redone.
sleep 2s
touch sub/package/dropbear/dropbear.mk
make $MAKE_ARGS > third.out
grep -q "MAKE" third.out
if grep -q "BUILDROOT" third.out
then
    exit 1
fi

# Touching a Config.in redoes the configuration, and then the build.
sleep 2s
touch sub/package/busybox/Config.in
make $MAKE_ARGS > fourth.out
grep -q "BUILDROOT" fourth.out
grep -q "MAKE" fourth.out

# So does touching something in the external tree, which is this
# project's own code rather than anything the vendored tree knows
# about.
sleep 2s
touch ext/package/mine/mine.mk
make $MAKE_ARGS > fifth.out
grep -q "MAKE" fifth.out

##############################################################################
# Cleaning                                                                   #
##############################################################################
# A vendored build lands in this project's object directory, where
# cache-clean would otherwise read the Makefile back, find that it
# says nothing about any of it, and throw away a build that's
# perfectly good.
make $MAKE_ARGS cache-clean
test -f obj/buildroot/sub/build/.config
test -f obj/buildroot/sub/build/images.txt
make $MAKE_ARGS > sixth.out
if grep -q "MAKE" sixth.out
then
    exit 1
fi

# Undoing a configure throws away what the vendored build system
# produced, and leaves both the vendored tree and the external tree
# exactly as they were.
make $MAKE_ARGS distclean
test ! -e obj/buildroot
test ! -e sub/output
test -f sub/Makefile
test -f sub/Config.in
test -f sub/package/dropbear/dropbear.mk
test -f ext/package/mine/mine.mk
grep -q "^O ?= " sub/Makefile

exit 0
