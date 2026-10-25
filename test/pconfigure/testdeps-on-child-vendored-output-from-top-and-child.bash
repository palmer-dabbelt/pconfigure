#include "harness_start.bash"

# A vendored tree belonging to a subproject, whose named output is
# waited for by a test in that subproject and by a test at the top.
# The child names it the short way, from its own tree's name; the top
# names it as an ordinary path into the child's object directory.  Both
# have to come out as the one rule the child's Makefile writes, and
# both tests have to run after the tree was built -- from the top, and
# from the child through the Makefile the top wrote for it.
mkdir -p child/vend/configs child/test/integration test/top

cat >child/vend/Kconfig <<'EOF'
config BASE
	bool "base"
	default y
EOF

echo CONFIG_BASE=y > child/vend/configs/tiny_defconfig

cat >child/vend/Makefile <<'EOF'
O ?= $(CURDIR)/build
all: $(O)/.config
	@echo made > $(O)/made
tiny_defconfig:
	@mkdir -p $(O)
	@cp $(CURDIR)/configs/tiny_defconfig $(O)/.config
EOF

cat >child/Configfile <<'EOF'
BUILD_SYSTEMS      += kconfig
SUBPROJECTS        += vend
CONFIGUREOPTS      += --defconfig tiny_defconfig
SUBPROJECT_TARGETS += made

LANGUAGES          += bash
PHONY              += integration
TESTDEPS           += vend/build/made
TESTSRC            += inner.bash
EOF

# $PTEST_SRCDIR is the project the test belongs to, wherever make was
# run from.
echo 'test "$(cat "$PTEST_SRCDIR/obj/vend/build/made")" = made' \
    > child/test/integration/inner.bash

cat >Configfile <<'EOF'
SUBPROJECTS += child

LANGUAGES   += bash
PHONY       += top
TESTDEPS    += child/obj/vend/build/made
TESTSRC     += outer.bash
EOF

echo 'test "$(cat "$PTEST_SRCDIR/child/obj/vend/build/made")" = made' \
    > test/top/outer.bash

$PTEST_BINARY $PCONFIGURE_ARGS

grep -q "^check/top/outer.bash: .* child/obj/vend/build/made$" Makefile
grep -q "^\$(pconfigure_subdir_child)check/integration/inner.bash: .* \$(pconfigure_subdir_child)obj/vend/build/made$" child/obj/Makefile.child

make $MAKE_ARGS -j2 check

ptest="$(dirname "$PTEST_BINARY")/ptest"
$ptest --no-check-make-check > report.out
cat report.out
grep -q "PASS	top/outer.bash" report.out
grep -q "PASS	child/integration/inner.bash" report.out

# And from inside the child, through the Makefile the top wrote for it,
# with the tree's output taken away so that only the rule can bring it
# back.
rm -rf child/obj/vend/build child/check
(cd child && make $MAKE_ARGS -f obj/Makefile.child check)
tar -xOf child/check/integration/inner.bash ptest__return > inner.ret
test "$(cat inner.ret)" = "0"

exit 0
