#include "harness_start.bash"

# A kconfig tree's ".config" is a file the tree has once it is built,
# so it is a thing somebody names with SUBPROJECT_TARGETS when a test
# wants to read the configuration it ran against.  It is also the one
# file in the build directory that pconfigure already has a rule for:
# the configure step writes it.  A second rule for it is make's
# "overriding recipe" warning, and the recipe that wins is the one that
# only checks the file is there -- so the configuration is never made
# and the build stops claiming the tree didn't build it.  The file has
# a rule already, so the line is taken as asking for nothing more than
# that rule.
mkdir -p k/configs

cat >Configfile <<EOF
BUILD_SYSTEMS      += kconfig

SUBPROJECTS        += k
CONFIGUREOPTS      += --defconfig tiny_defconfig
SUBPROJECT_TARGETS += .config
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
	@echo built > $(O)/built
tiny_defconfig:
	@mkdir -p $(O)
	@cp $(CURDIR)/configs/tiny_defconfig $(O)/.config
EOF

$PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1 || { cat configure.out; exit 1; }
cat configure.out

make $MAKE_ARGS > make.out 2>&1 || { cat make.out; exit 1; }
cat make.out
if grep -q "overriding recipe" make.out
then
    exit 1
fi
test "$(cat obj/k/build/.config)" = "CONFIG_BASE=y"
test -f obj/k/build/built

exit 0
