#include "harness_start.bash"

# A SUBPROJECT_TARGETS that wanders and comes back -- "d/../d/f" -- is
# the same file as "d/f", so naming both is one output with one rule,
# not two recipes for one target.
mkdir -p k/configs

cat >Configfile <<'EOF'
BUILD_SYSTEMS      += kconfig
SUBPROJECTS        += k
CONFIGUREOPTS      += --defconfig tiny_defconfig
SUBPROJECT_TARGETS += d/../d/f
SUBPROJECT_TARGETS += d/f
EOF

cat >k/Kconfig <<'EOF'
config BASE
	bool "base"
	default y
EOF

echo CONFIG_BASE=y > k/configs/tiny_defconfig

cat >k/Makefile <<'EOF'
O ?= $(CURDIR)/build
all: $(O)/.config
	@mkdir -p $(O)/d
	@echo x > $(O)/d/f
tiny_defconfig:
	@mkdir -p $(O)
	@cp $(CURDIR)/configs/tiny_defconfig $(O)/.config
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
test "$(grep -c '^obj/k/build/d/f: obj/k/build-stamp$' Makefile)" = "1"
if grep -q "build/d/\.\./" Makefile
then
    exit 1
fi

make $MAKE_ARGS > make.out 2>&1
cat make.out
if grep -q "overriding recipe" make.out
then
    exit 1
fi
test -f obj/k/build/d/f

exit 0
