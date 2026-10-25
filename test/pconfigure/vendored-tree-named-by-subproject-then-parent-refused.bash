#include "harness_start.bash"

# A vendored tree that two projects in one run both ask for: the
# subproject "a" vendors its own "k", and the top names "a/k" as well.
# Inside one Configfile a second line naming a tree lands on the tree
# the first one bound, but across two projects there is no one tree
# for it to land on -- each project builds what it binds into its own
# object directory -- so both bindings were kept, and a parallel make
# ran two recursive makes over the one source tree at once.  The
# second line is refused instead, and the complaint names both lines
# so whoever reads it can pick which project keeps the tree.
#
# Here "a" is read first, so the top's line is the second one.
mkdir -p a/k/configs

cat >a/k/Kconfig <<'EOF'
config BASE
	bool "base"
	default y
EOF

echo CONFIG_BASE=y > a/k/configs/tiny_defconfig

cat >a/k/Makefile <<'EOF'
O ?= $(CURDIR)/build
all: $(O)/.config
	@echo built >> $(O)/built
tiny_defconfig:
	@mkdir -p $(O)
	@cp $(CURDIR)/configs/tiny_defconfig $(O)/.config
EOF

cat >a/Configfile <<'EOF'
BUILD_SYSTEMS += kconfig
SUBPROJECTS   += k
CONFIGUREOPTS += --defconfig tiny_defconfig
EOF

cat >Configfile <<'EOF'
BUILD_SYSTEMS += kconfig
SUBPROJECTS   += a
SUBPROJECTS   += a/k
CONFIGUREOPTS += --defconfig tiny_defconfig
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
then
    cat configure.out
    exit 1
fi
cat configure.out

grep -qF "Configfile:3 'SUBPROJECTS += a/k'" configure.out
grep -qF "a/Configfile:2 'SUBPROJECTS += k'" configure.out
test ! -e Makefile

exit 0
