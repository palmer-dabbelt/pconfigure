#include "harness_start.bash"

# A CONFIG_DEPS on a file a vendored tree installs, in a project that
# did not ask for AUTORECONFIGURE and keeps no committed Makefile.
#
# With no recipe anywhere, a prerequisite of the Makefile could never
# lead to a reconfigure.  What it would still do is have make remake
# the tool while remaking the makefiles it includes, which happens
# before make looks at the goal and under -n too: "make clean" or
# "make -n" on a tree that vendors LLVM would be a build of LLVM.  A
# $(wildcard) only hides that until the tool first exists, so the
# interesting case is a built tree whose sources then change.  Such a
# project names nothing, and a dry run or a clean leaves the tree
# alone whatever state it is in.

mkdir -p wrap tree/configs Configfiles

cat >Configfile <<'CONFIGFILE'
SUBPROJECTS    += wrap
CONFIG         += probe
CONFIGFILE

cat >Configfiles/probe <<'PROBE'
#!/bin/bash
echo "CONFIG_DEPS += wrap/obj/tree/build/bin/tool"
PROBE
chmod +x Configfiles/probe

cat >wrap/Configfile <<'CONFIGFILE'
BUILD_SYSTEMS      += kconfig
SUBPROJECTS        += ../tree
CONFIGUREOPTS      += --defconfig tiny_defconfig
SUBPROJECT_TARGETS += bin/tool
CONFIGFILE

cat >tree/Kconfig <<'KCONFIG'
config BASE
	bool "base"
	default y
KCONFIG

cat >tree/configs/tiny_defconfig <<'DEFCONFIG'
CONFIG_BASE=y
DEFCONFIG

# Leaves a mark each time anything runs its build or its configure,
# which is the thing this test is looking for.
cat >tree/Makefile <<'MAKEFILE'
O ?= $(CURDIR)/build

all: $(O)/.config
	@mkdir -p $(O)/bin
	@echo tool > $(O)/bin/tool
	@echo built >> $(CURDIR)/../tree-was-built

tiny_defconfig:
	@mkdir -p $(O)
	@echo configured >> $(CURDIR)/../tree-was-configured
	@cp $(CURDIR)/configs/tiny_defconfig $(O)/.config
MAKEFILE

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
if grep -q '^Makefile:' Makefile
then
    exit 1
fi

# A fresh tree: a dry run of the clean rather than of the default goal,
# since a dry run of the build itself runs the tree's own make under
# -n, as it should.  What is being asked is whether make builds the
# tree while it is remaking makefiles.
make $MAKE_ARGS -n clean > dry-run.log 2>&1 || { cat dry-run.log; exit 1; }
cat dry-run.log
test ! -e wrap/obj/tree/build/bin/tool
test ! -e tree-was-built
test ! -e tree-was-configured

make $MAKE_ARGS clean > clean.log 2>&1 || { cat clean.log; exit 1; }
cat clean.log
test ! -e wrap/obj/tree/build/bin/tool
test ! -e tree-was-built

# A build that asks for the tree still builds it, of course.
make $MAKE_ARGS > all.log 2>&1 || { cat all.log; exit 1; }
cat all.log
test -e wrap/obj/tree/build/bin/tool
test "$(wc -l < tree-was-built)" = 1

# Now the tool exists and the tree's sources move on, so the tool is
# out of date.  Neither a dry run nor a clean is a reason to build it.
sleep 1
touch tree/Kconfig tree/Makefile tree/configs/tiny_defconfig
rm -f tree-was-configured

make $MAKE_ARGS -n clean > dry-run-2.log 2>&1 || { cat dry-run-2.log; exit 1; }
cat dry-run-2.log
test "$(wc -l < tree-was-built)" = 1
test ! -e tree-was-configured

make $MAKE_ARGS clean > clean-2.log 2>&1 || { cat clean-2.log; exit 1; }
cat clean-2.log
test "$(wc -l < tree-was-built)" = 1
test ! -e tree-was-configured
