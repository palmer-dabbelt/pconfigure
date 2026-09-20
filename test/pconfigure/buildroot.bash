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
CONFIGUREOPTS += --env MY_FLAGS=-O2 -g

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
grep -q "^obj/sub/build/.config:" Makefile
grep -q "^obj/sub/build-stamp:" Makefile
grep -q "^all: obj/sub/build-stamp$" Makefile
if grep -q "include sub/Makefile" Makefile
then
    exit 1
fi

# A tree with a Config.in in it isn't a kbuild tree, so the kconfig
# build system doesn't get a chance to claim it -- and it wasn't even
# asked for here.  Which one claimed it is what make prints while it
# configures the tree, since the output directory is named after the
# tree rather than after whatever builds it.
if grep -q "KCONFIG" Makefile
then
    exit 1
fi
grep -q "BUILDROOT" Makefile

# And what it inherits, it really does inherit.  buildroot writes no
# --env handling of its own -- it is a kconfig tree with different
# files in it -- so the quoting that keeps the second word of a value
# from being run as a command of its own is something it gets for
# free.  "For free" is worth an assertion: the day somebody gives this
# build system an environment of its own is the day the quoting stops
# being inherited, and nothing else here would notice.
grep -q "MY_FLAGS='-O2 -g'" Makefile
if grep -q "MY_FLAGS=-O2 -g" Makefile
then
    exit 1
fi

# The whole configuration was chased, out of Config.in rather than out
# of a Kconfig.
grep -q "^obj/sub/build/.config:.* sub/Config.in" Makefile
grep -q "^obj/sub/build/.config:.* sub/Config.in.legacy" Makefile
grep -q "^obj/sub/build/.config:.* sub/package/Config.in" Makefile
grep -q "^obj/sub/build/.config:.* sub/package/busybox/Config.in" Makefile
grep -q "^obj/sub/build/.config:.* sub/package/dropbear/Config.in" Makefile
grep -q "^obj/sub/build/.config:.* sub/fs/Config.in" Makefile
grep -q "^obj/sub/build/.config:.* sub/configs/tiny_defconfig" Makefile

# So was the build description, which a buildroot tree includes by
# wildcard rather than by naming one file at a time.  A package that
# isn't even enabled is still a file this configuration might read
# tomorrow.
grep -q "^obj/sub/build-stamp:.* sub/Makefile" Makefile
grep -q "^obj/sub/build-stamp:.* sub/support/misc/utils.mk" Makefile
grep -q "^obj/sub/build-stamp:.* sub/package/busybox/busybox.mk" Makefile
grep -q "^obj/sub/build-stamp:.* sub/package/dropbear/dropbear.mk" Makefile
grep -q "^obj/sub/build-stamp:.* sub/fs/ext2/ext2.mk" Makefile
grep -q "^obj/sub/build-stamp:.* sub/linux/linux.mk" Makefile

# An external tree is reached through a variable that names it, so
# nothing in the vendored tree points at it: what it holds is named
# because BR2_EXTERNAL says what such a tree is made of.
grep -q "BR2_EXTERNAL=" Makefile
grep -q "^obj/sub/build/.config:.* ext/Config.in" Makefile
grep -q "^obj/sub/build/.config:.* ext/package/mine/Config.in" Makefile
grep -q "^obj/sub/build-stamp:.* ext/external.desc" Makefile
grep -q "^obj/sub/build-stamp:.* ext/external.mk" Makefile
grep -q "^obj/sub/build-stamp:.* ext/package/mine/mine.mk" Makefile

# And that list is all there is going to be.  A kbuild tree also
# writes down what its BUILD read, a file at a time beside each
# object, and gets a second fragment out of reading them; buildroot
# writes nothing of the kind, so there is nothing to read and no
# reason to go looking.  Not going looking is the point: a buildroot
# output directory holds whole source trees of its own, one of them a
# kernel, and walking it to collect an answer that would be thrown
# away for belonging to the output costs minutes.
if grep -q "build-deps" Makefile
then
    exit 1
fi
if test -e obj/sub/build-deps-context
then
    exit 1
fi

##############################################################################
# Building                                                                   #
##############################################################################
make $MAKE_ARGS

# The defconfig was applied, and then the options on top of it.
grep -q "^BR2_BASE=y$" obj/sub/build/.config
grep -q "^BR2_PACKAGE_BUSYBOX=y$" obj/sub/build/.config
grep -q "^BR2_PACKAGE_DROPBEAR=y$" obj/sub/build/.config
grep -q "^# olddefconfig$" obj/sub/build/.config

# A value that was written with quotes around it is a string, and a
# string keeps its quotes in a .config -- which is the tree's own
# program's job, and the reason it gets told which kind this is.
grep -q '^BR2_TARGET_GENERIC_HOSTNAME="my router"$' obj/sub/build/.config

test -f obj/sub/build/images.txt
test -f obj/sub/build-stamp
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
test -f obj/sub/build/.config
test -f obj/sub/build/images.txt
make $MAKE_ARGS > sixth.out
if grep -q "MAKE" sixth.out
then
    exit 1
fi

# Undoing a configure throws away what the vendored build system
# produced, and leaves both the vendored tree and the external tree
# exactly as they were.
make $MAKE_ARGS distclean
test ! -e obj/sub
test ! -e sub/output
test -f sub/Makefile
test -f sub/Config.in
test -f sub/package/dropbear/dropbear.mk
test -f ext/package/mine/mine.mk
grep -q "^O ?= " sub/Makefile

##############################################################################
# An --external names a directory inside the project that wrote it           #
##############################################################################
# A BR2_EXTERNAL tree is the vendoring project's own code, so it is
# written relative to that project the same way a SUBPROJECTS is --
# and it reaches the Makefile through that project's own prefix
# variable, which is what makes one line name one directory whether
# make runs at the top or inside the subproject.
#
# This asked nothing at all: it resolved the path against the project
# and checked only that something was there.  So a subproject's
# "--external ../ext" came out as "ext/" from a run at the top and as
# "../ext/" from a run inside, with no variable in front of either --
# one line, two spellings, and buildroot writes the list it was given
# into its output directory and complains when a later make disagrees.
merge_tree()
{
    mkdir -p "$1/package/thing" "$1/support/kconfig" "$1/utils"

    cat >"$1/Config.in" <<'EOF'
config BR2_BASE
	bool "base"
	default y
EOF

    cat >"$1/Makefile" <<'EOF'
O ?= $(CURDIR)/output

all:
	@mkdir -p $(O)
EOF

    cat >"$1/package/Config.in" <<'EOF'
source "package/thing/Config.in"
EOF
}

mkdir -p outside/sub outside/ext/package/mine
merge_tree outside/sub/br
touch outside/ext/external.desc outside/ext/external.mk
touch outside/ext/Config.in

cat >outside/Configfile <<'EOF'
SUBPROJECTS += sub
EOF

cat >outside/sub/Configfile <<'EOF'
BUILD_SYSTEMS += buildroot

SUBPROJECTS   += br
CONFIGUREOPTS += --external ../ext
EOF

if (cd outside && $PTEST_BINARY $PCONFIGURE_ARGS) > outside.out 2>&1
then
    exit 1
fi
cat outside.out
grep -qF "'--external ../ext' reaches outside the project that wrote it" \
    outside.out
grep -q "like '--external br2-external'" outside.out
test ! -e outside/Makefile
test ! -e outside/sub/obj/Makefile.sub

# And from inside the subproject, which used to be the reading that
# was accepted -- with a different answer than the one above, out of
# the same line.
mkdir -p outside/sub/ext/package/mine
touch outside/sub/ext/external.desc outside/sub/ext/external.mk
touch outside/sub/ext/Config.in

if (cd outside/sub && $PTEST_BINARY $PCONFIGURE_ARGS) \
    > outside-inside.out 2>&1
then
    exit 1
fi
cat outside-inside.out
grep -qF "'--external ../ext' reaches outside the project that wrote it" \
    outside-inside.out
test ! -e outside/sub/Makefile

# An absolute one is the other way of naming a directory no Makefile
# here owns, and it used to be accepted outright: buildroot wants the
# list absolutely, so the "$(abspath ...)" that gets written round it
# hid the whole question.
mkdir -p absolute/br2-external/package/mine
merge_tree absolute/br
touch absolute/br2-external/external.desc

cat >absolute/Configfile <<EOF
BUILD_SYSTEMS += buildroot

SUBPROJECTS   += br
CONFIGUREOPTS += --external $tempdir/absolute/br2-external
EOF

if (cd absolute && $PTEST_BINARY $PCONFIGURE_ARGS) > absolute.out 2>&1
then
    exit 1
fi
cat absolute.out
grep -q "is an absolute path" absolute.out
test ! -e absolute/Makefile

# And the spelling that does work, which is what says the refusals
# above are about where the directory is rather than about the option.
mkdir -p inside/br2-external/package/mine
merge_tree inside/br
touch inside/br2-external/external.desc inside/br2-external/external.mk
touch inside/br2-external/Config.in

cat >inside/Configfile <<'EOF'
BUILD_SYSTEMS += buildroot

SUBPROJECTS   += br
CONFIGUREOPTS += --external br2-external
EOF

(cd inside && $PTEST_BINARY $PCONFIGURE_ARGS)
grep -q -- "BR2_EXTERNAL=\$(abspath br2-external/)" inside/Makefile

# And the list arrives as one word, quoted whole the way every
# variable a --make-var wrote is quoted by makeopt_flags().  It is one
# variable on a make command line like those, so it wants the same
# treatment: what is inside the quotes is still expanded, because make
# reads the line before the shell ever sees it, and it is still
# rewritten for a subproject, because path_prefix::rewrite() reads a
# quote as the end of one word and the start of the next.
grep -q -- "'BR2_EXTERNAL=\$(abspath br2-external/)'" inside/Makefile

##############################################################################
# A second answer to where buildroot builds, or to where it puts what        #
# it built                                                                   #
##############################################################################
# buildroot inherits every one of these from kconfig, and then adds
# the directories it gave names of its own: it took the shape of
# kbuild's command line and then called the output directory
# BASE_DIR, the filesystem it assembles TARGET_DIR, the images
# BINARIES_DIR, and so on.  Every one of them is a plain '=' in
# buildroot's own Makefile, so a variable of that name on the
# sub-make's command line replaces it outright.
#
# Before this, neither build system overrode take_makeopt() or
# already_answered(), so the "DESTDIR=" autotools, cmake and cargo
# each refused was taken here without a word -- and a plain "make"
# then staged an install wherever the line pointed.
br_tree()
{
    mkdir -p "$1/package/thing" "$1/utils"

    cat >"$1/Config.in" <<'EOF'
config BR2_BASE
	bool "base"
	default y
EOF

    cat >"$1/Makefile" <<'EOF'
O ?= $(CURDIR)/output

all:
	@mkdir -p $(O)

defconfig:
	@mkdir -p $(O)
	@touch $(O)/.config
EOF

    cat >"$1/package/Config.in" <<'EOF'
source "package/thing/Config.in"
EOF
}

second_answer()
{
    dir="$1"

    mkdir -p "$dir"
    br_tree "$dir/br"

    {
        echo "BUILD_SYSTEMS += buildroot"
        echo ""
        echo "SUBPROJECTS   += br"
        shift
        for line in "$@"
        do
            echo "$line"
        done
    } > "$dir/Configfile"
    cat "$dir/Configfile"

    if (cd "$dir" && $PTEST_BINARY $PCONFIGURE_ARGS) > "$dir.out" 2>&1
    then
        exit 1
    fi
    cat "$dir.out"
    test ! -e "$dir/Makefile"
}

# What it inherits.  A command-line variable reaches every package's
# own make through MAKEFLAGS, so a DESTDIR at the top of buildroot is
# a DESTDIR in front of every install it runs.
second_answer sa-destdir "MAKEOPS += DESTDIR=$tempdir/elsewhere"
grep -q "^buildroot: 'MAKEOPS DESTDIR=$tempdir/elsewhere' sets 'DESTDIR'" \
    sa-destdir.out
grep -q "says where an install target of this tree writes" sa-destdir.out

second_answer sa-o "CONFIGUREOPTS += --make-var O=$tempdir/elsewhere"
grep -q "^buildroot: '--make-var O=$tempdir/elsewhere' sets 'O'" sa-o.out

# And what it adds.  TARGET_DIR is the filesystem buildroot assembles
# -- which is what a project vendoring buildroot is after -- and it is
# derived from the "O=" this build system wrote, so a second answer
# leaves the images somewhere nothing here names.
second_answer sa-target-dir \
    "CONFIGUREOPTS += --make-var TARGET_DIR=$tempdir/elsewhere"
grep -q "sets 'TARGET_DIR'" sa-target-dir.out
grep -q "says where part of what buildroot builds is assembled" \
    sa-target-dir.out

second_answer sa-host-dir \
    "CONFIGUREOPTS += --env HOST_DIR=$tempdir/elsewhere"
grep -q "sets 'HOST_DIR'" sa-host-dir.out

second_answer sa-staging-dir \
    "MAKEOPS += STAGING_DIR=$tempdir/elsewhere"
grep -q "sets 'STAGING_DIR'" sa-staging-dir.out

second_answer sa-binaries-dir \
    "CONFIGUREOPTS += --make-var BINARIES_DIR=$tempdir/elsewhere"
grep -q "sets 'BINARIES_DIR'" sa-binaries-dir.out

second_answer sa-base-dir \
    "CONFIGUREOPTS += --make-var BASE_DIR=$tempdir/elsewhere"
grep -q "sets 'BASE_DIR'" sa-base-dir.out
grep -q "says where the tree builds" sa-base-dir.out

second_answer sa-build-dir \
    "CONFIGUREOPTS += --make-var BUILD_DIR=$tempdir/elsewhere"
grep -q "sets 'BUILD_DIR'" sa-build-dir.out

# PER_PACKAGE_DIR sits beside BUILD_DIR in already_answered() rather
# than beside BR2_DL_DIR: it's buildroot's own per-package build
# output, holding exactly what BUILD_DIR holds split one directory per
# package, so a word that redirects it is the same hazard BUILD_DIR
# already refuses one directory further down.
second_answer sa-per-package-dir \
    "CONFIGUREOPTS += --make-var PER_PACKAGE_DIR=$tempdir/elsewhere"
grep -q "sets 'PER_PACKAGE_DIR'" sa-per-package-dir.out
grep -q "says where the tree builds" sa-per-package-dir.out

second_answer sa-per-package-dir-makeops \
    "MAKEOPS += PER_PACKAGE_DIR=$tempdir/elsewhere"
grep -q "sets 'PER_PACKAGE_DIR'" sa-per-package-dir-makeops.out

second_answer sa-topdir "CONFIGUREOPTS += --make-var TOPDIR=$tempdir/elsewhere"
grep -q "sets 'TOPDIR'" sa-topdir.out

# And the list of external trees, which '--external' has already
# written onto this same command line -- where a second one does not
# quietly win but quietly loses: buildroot writes the list it was
# first given into its output directory and stops a later make that
# disagrees with it.
mkdir -p sa-external/other/package/mine
touch sa-external/other/external.desc sa-external/other/external.mk
touch sa-external/other/Config.in
second_answer sa-external "CONFIGUREOPTS += --make-var BR2_EXTERNAL=other"
grep -q "sets 'BR2_EXTERNAL'" sa-external.out
grep -q "'--external' has already written onto this command line" \
    sa-external.out

##############################################################################
# One option is one target                                                   #
##############################################################################
# Inherited from kconfig along with everything else, and asserted here
# for the reason the --env quoting above is: buildroot writes no
# --target handling of its own, so the day it does is the day this
# stops being true and nothing else would notice.
mkdir -p inject
br_tree inject/br
cat >>inject/br/Makefile <<'EOF'

.DEFAULT:
	@mkdir -p $(O)
EOF

cat >inject/Configfile <<EOF
BUILD_SYSTEMS += buildroot

SUBPROJECTS   += br
CONFIGUREOPTS += --target all; touch $tempdir/PWNED-BUILDROOT
EOF

(cd inject && $PTEST_BINARY $PCONFIGURE_ARGS)
cat inject/Makefile
grep -qF "'all; touch $tempdir/PWNED-BUILDROOT'" inject/Makefile

rm -f $tempdir/PWNED-BUILDROOT
(cd inject && make $MAKE_ARGS)
test ! -e $tempdir/PWNED-BUILDROOT

exit 0
