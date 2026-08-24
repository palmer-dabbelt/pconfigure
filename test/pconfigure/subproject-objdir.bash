#include "harness_start.bash"

# A vendored tree's output directory is named after the tree and after
# nothing else.  It used to carry two more things: the build system
# that was picked for it, which nobody who reads the Configfile chose,
# and the whole path to the tree, which starts with "src" for every
# subproject that lives where the sources live.  Both of those made
# the path longer without telling any two trees apart.
mkdir -p src vendor

##############################################################################
# Two trees that look enough like Linux to be picked up as kbuild ones       #
##############################################################################
for tree in src/linux vendor/br
do
    mkdir -p $tree/configs

    cat >$tree/Kconfig <<'EOF'
config BASE
	bool "base"
	default y
EOF

    cat >$tree/configs/tiny_defconfig <<'EOF'
CONFIG_BASE=y
EOF

    cat >$tree/Makefile <<'EOF'
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
EOF
done

# One tree is vendored under the source directory, which is where a
# subproject usually goes, and the other isn't -- so the "src" that
# comes off the front of the first one is the source directory rather
# than any directory that happens to be called that.
cat >Configfile <<EOF
BUILD_SYSTEMS += kconfig

SUBPROJECTS   += src/linux
CONFIGUREOPTS += --defconfig tiny_defconfig

SUBPROJECTS   += vendor/br
CONFIGUREOPTS += --defconfig tiny_defconfig

LANGUAGES   += c
BINARIES    += test
SOURCES     += test.c
EOF

cat >src/test.c <<EOF
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# The tree under the source directory builds into a directory named
# after the tree alone.
grep -q "^obj/linux/build/.config:" Makefile
grep -q "^obj/linux/build-stamp:" Makefile
test -f obj/linux/configure-opts

# The one outside it keeps the path it was vendored at, since there's
# nothing on the front of that to take off.
grep -q "^obj/vendor/br/build/.config:" Makefile
grep -q "^obj/vendor/br/build-stamp:" Makefile
test -f obj/vendor/br/configure-opts

# Which build system was picked doesn't appear in any of it.
if grep -q "obj/kconfig" Makefile
then
    exit 1
fi

# Neither does the source directory the first tree was vendored under.
if grep -q "obj/src/linux" Makefile
then
    exit 1
fi

# Taking "src" off is what keeps a vendored tree clear of pconfigure's
# own object files, which keep the source path they were compiled from
# and so all live under "obj/src".
grep -q "^obj/src/test.c/.*\.o: src/test.c$" Makefile

# All of which builds.
make $MAKE_ARGS

test -f obj/linux/build/built.txt
test -f obj/linux/build-stamp
test -f obj/vendor/br/build/built.txt
test -f obj/vendor/br/build-stamp
test -d obj/src/test.c
test -f bin/test

# And nothing was written inside either tree.
test ! -e src/linux/build
test ! -e vendor/br/build

exit 0
