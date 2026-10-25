#include "harness_start.bash"

# The other order of a vendored tree two projects in one run both ask
# for: the top names "a/k" before it reads "a", whose own Configfile
# vendors the same tree as "k".  Whichever project's line comes
# second is the one refused, so here it is a's, and the complaint
# still names both lines.
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
SUBPROJECTS   += a/k
CONFIGUREOPTS += --defconfig tiny_defconfig
SUBPROJECTS   += a
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
then
    cat configure.out
    exit 1
fi
cat configure.out

grep -qF "a/Configfile:2 'SUBPROJECTS += k'" configure.out
grep -qF "Configfile:2 'SUBPROJECTS += a/k'" configure.out
test ! -e Makefile

exit 0
