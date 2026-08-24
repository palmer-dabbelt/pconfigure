#include "harness_start.bash"

mkdir -p src sub/configs sub/scripts sub/drivers/extra
mkdir -p sub/arch/one sub/arch/two psub/src

# The vendored tree is pulled in the same way any other subproject is,
# and nothing inside it says a word about pconfigure: BUILD_SYSTEMS
# says kconfig is available, and which subproject gets built that way
# is worked out from what's in the directory.
cat >Configfile <<EOF
BUILD_SYSTEMS += kconfig

SUBPROJECTS   += sub
CONFIGUREOPTS += --defconfig tiny_defconfig
CONFIGUREOPTS += --configure CONFIG_EXTRA=y

SUBPROJECTS   += psub

LANGUAGES   += c
BINARIES    += test
SOURCES     += test.c
EOF

cat >src/test.c <<EOF
int main(void) { return 0; }
EOF

# A pconfigure subproject sitting right next to the vendored one, to
# show that having kconfig available doesn't change what happens to a
# directory that has a Configfile in it.
cat >psub/Configfile <<EOF
LANGUAGES += c

LIBRARIES += libpsub.so
SOURCES   += psub.c
EOF

cat >psub/src/psub.c <<EOF
int psub(void) { return 3; }
EOF

##############################################################################
# A tree that looks enough like Linux to be worth chasing                    #
##############################################################################
cat >sub/Kconfig <<'EOF'
config BASE
	bool "base"
	default y

source "drivers/Kconfig"
source "arch/$(SRCARCH)/Kconfig"
EOF

cat >sub/drivers/Kconfig <<'EOF'
config EXTRA
	bool "extra"
EOF

cat >sub/arch/one/Kconfig <<'EOF'
config ONE
	bool "one"
EOF

cat >sub/arch/two/Kconfig <<'EOF'
config TWO
	bool "two"
EOF

cat >sub/configs/tiny_defconfig <<'EOF'
CONFIG_BASE=y
EOF

# The vendored build system's own Makefile, which is the one thing
# pconfigure must not write over.
cat >sub/Makefile <<'EOF'
O ?= $(CURDIR)/build

all: $(O)/.config
	@mkdir -p $(O)
	@cp $(O)/.config $(O)/built.txt

tiny_defconfig:
	@mkdir -p $(O)
	@cp $(CURDIR)/configs/tiny_defconfig $(O)/.config

olddefconfig:
	@mkdir -p $(O)
	@echo "# olddefconfig" >> $(O)/.config

include drivers/Makefile
EOF

cat >sub/drivers/Makefile <<'EOF'
obj-y += driver.o
obj-$(CONFIG_EXTRA) += extra/
EOF

cat >sub/drivers/extra/Makefile <<'EOF'
obj-y += extra.o
EOF

cat >sub/drivers/driver.c <<'EOF'
int driver(void) { return 1; }
EOF

cat >sub/drivers/extra/extra.c <<'EOF'
int extra(void) { return 2; }
EOF

cat >sub/scripts/config <<'EOF'
#!/bin/bash
set -e
file=.config
while [[ "$#" -gt 0 ]]
do
    case "$1" in
    --file)    file="$2";                        shift 2;;
    --enable)  echo "$2=y" >> "$file";           shift 2;;
    --module)  echo "$2=m" >> "$file";           shift 2;;
    --disable) echo "# $2 is not set" >> "$file"; shift 2;;
    --set-val) echo "$2=$3" >> "$file";          shift 3;;
    *)                                            shift 1;;
    esac
done
EOF
chmod +x sub/scripts/config

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# Nothing at all was written inside the vendored tree.  Its Makefile
# in particular is the file its build system reads, and writing one
# over it would destroy the thing we were asked to build.
grep -q "^O ?= " sub/Makefile
test ! -e sub/obj
test ! -e sub/Configfile

# The one thing configure time does write on this side of the fence is
# the list of options the tree is about to be configured with, which
# has to exist before make runs because make is what compares it
# against the last one.  The build directory itself is still make's to
# create.
test -f obj/sub/configure-opts
test ! -e obj/sub/build
test ! -e obj/sub/build-stamp

# The rules that drive it live in the Makefile of whoever pulled it
# in, since there's nowhere else for them to go.
grep -q "^obj/sub/build/.config:" Makefile
grep -q "^obj/sub/build-stamp:" Makefile
grep -q "^all: obj/sub/build-stamp$" Makefile
if grep -q "include sub/Makefile" Makefile
then
    exit 1
fi

# The subproject that does have a Configfile is still read as a
# pconfigure project and still gets a Makefile of its own, which is
# the implicit "BUILD_SYSTEMS += pconfigure" doing its job.
test -f psub/Makefile
grep -q "^include \$(pconfigure_subdir_psub)Makefile$" Makefile
if grep -q "obj/psub" Makefile
then
    exit 1
fi

# The dependencies were chased at configure time: every Kconfig the
# top one reaches, and every source an object could have come from --
# including the ones behind a config symbol that isn't set yet.
grep -q "^obj/sub/build/.config:.* sub/Kconfig" Makefile
grep -q "^obj/sub/build/.config:.* sub/drivers/Kconfig" Makefile
grep -q "^obj/sub/build/.config:.* sub/configs/tiny_defconfig" Makefile

# A path a variable made unreadable becomes a glob, since
# "arch/$(SRCARCH)/Kconfig" names a real file for every value SRCARCH
# could take and this run has no idea which one it'll be.
grep -q "^obj/sub/build/.config:.* sub/arch/one/Kconfig" Makefile
grep -q "^obj/sub/build/.config:.* sub/arch/two/Kconfig" Makefile
grep -q "^obj/sub/build-stamp:.* sub/Makefile" Makefile
grep -q "^obj/sub/build-stamp:.* sub/drivers/Makefile" Makefile
grep -q "^obj/sub/build-stamp:.* sub/drivers/extra/Makefile" Makefile
grep -q "^obj/sub/build-stamp:.* sub/drivers/driver.c" Makefile
grep -q "^obj/sub/build-stamp:.* sub/drivers/extra/extra.c" Makefile

##############################################################################
# Building                                                                   #
##############################################################################
make $MAKE_ARGS

# The defconfig was applied, and then the options on top of it.
grep -q "^CONFIG_BASE=y$" obj/sub/build/.config
grep -q "^CONFIG_EXTRA=y$" obj/sub/build/.config
grep -q "^# olddefconfig$" obj/sub/build/.config
test -f obj/sub/build/built.txt
test -f obj/sub/build-stamp

# The pconfigure subproject built too, and the vendored tree is still
# untouched.
test -f psub/lib/libpsub.so
test ! -e sub/obj

# A second make in a tree that's already built doesn't recurse at all,
# which is the whole point of chasing those dependencies.
make $MAKE_ARGS > second.out
if grep -q "MAKE" second.out
then
    exit 1
fi

# Touching a source file that only exists because of a config symbol
# still gets us back into the vendored build system.
sleep 2s
touch sub/drivers/extra/extra.c
make $MAKE_ARGS > third.out
grep -q "MAKE" third.out
if grep -q "KCONFIG" third.out
then
    exit 1
fi

# Touching a Kconfig redoes the configuration, and then the build.
sleep 2s
touch sub/drivers/Kconfig
make $MAKE_ARGS > fourth.out
grep -q "KCONFIG" fourth.out
grep -q "MAKE" fourth.out

##############################################################################
# Cleaning                                                                   #
##############################################################################
# A vendored build lands in this project's object directory, where
# cache-clean would otherwise read the Makefile back, find that it
# says nothing about any of it, and throw away a build that's
# perfectly good.
make $MAKE_ARGS cache-clean
test -f obj/sub/build/.config
test -f obj/sub/build/built.txt
make $MAKE_ARGS > fifth.out
if grep -q "MAKE" fifth.out
then
    exit 1
fi

# make check still works in a project that vendors something, even
# though the vendored tree has no tests pconfigure knows how to run.
make $MAKE_ARGS check

# Undoing a configure throws away what the vendored build system
# produced, and leaves the vendored tree exactly as it was.
make $MAKE_ARGS distclean
test ! -e obj/sub
test ! -e sub/obj
test -f sub/Makefile
test -f sub/Kconfig
test -f sub/drivers/extra/extra.c
grep -q "^O ?= " sub/Makefile

exit 0
