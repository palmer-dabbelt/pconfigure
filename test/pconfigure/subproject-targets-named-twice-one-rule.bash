#include "harness_start.bash"

# One file named twice is one output, however the two lines spelled
# it.  Two rules for one target would be make's "overriding recipe"
# warning in the middle of a build, and two checks that the tree built
# the file.
mkdir -p k

cat >Configfile <<EOF
BUILD_SYSTEMS      += kconfig

SUBPROJECTS        += k
SUBPROJECT_TARGETS += out/image
SUBPROJECT_TARGETS += ./out//image
EOF

cat >k/Kconfig <<'EOF'
config X
	bool "x"
	default y
EOF

cat >k/Makefile <<'EOF'
O ?= $(CURDIR)/build
all:
	@mkdir -p $(O)/out
	@echo image > $(O)/out/image
defconfig:
	@mkdir -p $(O)
	@echo CONFIG_X=y > $(O)/.config
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
test "$(grep -c '^obj/k/build/out/image:' Makefile)" = "1"

make $MAKE_ARGS > make.out 2>&1
cat make.out
if grep -q "overriding recipe" make.out
then
    exit 1
fi
test "$(cat obj/k/build/out/image)" = "image"

exit 0
