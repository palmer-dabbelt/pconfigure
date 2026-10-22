#include "harness_start.bash"

# A vendored tree two lines ask for is built once, and the second
# line is how a Configfile gets back to the tree to say something more
# about it: a CONFIGUREOPTS after it lands on the one tree rather than
# on a second copy.  "k" and "./k/" are the same directory, so they are
# the same tree -- one rule that recurses into it, not two recipes
# racing each other in the same output directory.
mkdir -p k/configs

cat >Configfile <<EOF
BUILD_SYSTEMS += kconfig

SUBPROJECTS   += k
SUBPROJECTS   += ./k/
CONFIGUREOPTS += --defconfig tiny_defconfig
EOF

cat >k/Kconfig <<'EOF'
config BASE
	bool "base"
	default y
EOF

cat >k/configs/tiny_defconfig <<'EOF'
CONFIG_BASE=y
EOF

cat >k/Makefile <<'EOF'
O ?= $(CURDIR)/build
all: $(O)/.config
	@echo built >> $(O)/built
tiny_defconfig:
	@mkdir -p $(O)
	@cp $(CURDIR)/configs/tiny_defconfig $(O)/.config
EOF

$PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
cat out

# One configure and one build, the same two sub-makes a single
# SUBPROJECTS gets.
test "$(grep -cF -- '$(MAKE) --no-print-directory -C k ' Makefile)" = "2"
grep -q "tiny_defconfig" Makefile

make $MAKE_ARGS > make.out 2>&1
cat make.out
if grep -q "overriding recipe" make.out
then
    exit 1
fi
test "$(cat obj/k/build/built)" = "built"
grep -q CONFIG_BASE=y obj/k/build/.config

exit 0
