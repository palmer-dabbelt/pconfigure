#include "harness_start.bash"

# A vendored tree in a directory whose name starts with a dash.  The
# rule that builds it is a "$(MAKE) -C <dir>", and a "-C" with its
# argument in the next word takes that word whatever it looks like, so
# the name reaches make as a directory rather than as an option of its
# own -- and the tree builds, and builds once.
mkdir -p -- -k/configs

cat >-k/Kconfig <<'EOF'
config BASE
	bool "base"
	default y
EOF

echo CONFIG_BASE=y > -k/configs/tiny_defconfig

cat >-k/Makefile <<'EOF'
O ?= $(CURDIR)/build
all: $(O)/.config
	@echo built >> $(O)/built
tiny_defconfig:
	@mkdir -p $(O)
	@cp $(CURDIR)/configs/tiny_defconfig $(O)/.config
EOF

cat >Configfile <<'EOF'
BUILD_SYSTEMS += kconfig
SUBPROJECTS   += -k
CONFIGUREOPTS += --defconfig tiny_defconfig
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(cat obj/-k/build/built)" = "built"

make $MAKE_ARGS > again.out 2>&1
cat again.out
if grep -q "^MAKE	" again.out
then
    exit 1
fi

exit 0
