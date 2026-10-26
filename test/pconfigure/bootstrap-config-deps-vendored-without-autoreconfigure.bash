#include "harness_start.bash"

# The BOOTSTRAP counterpart to
# config-deps-vendored-without-autoreconfigure-clean-builds-nothing.bash.
# Without AUTORECONFIGURE a plain project names nothing for a
# CONFIG_DEPS, but a project that bootstraps has the recipe for it in
# its committed Makefile, so there the path is named -- and the
# vendored tool is named bare, as under AUTORECONFIGURE: make builds it
# before it decides whether to reconfigure, and the first make of a
# fresh tree configures against the tool rather than against its
# absence.

here="$(pwd)"

mkdir -p wrap tree/configs Configfiles vendor/pconfigure/src

cat >vendor/pconfigure/src/pconfigure.bash <<EOS
echo ran >> "$here/configures"
exec "$PTEST_BINARY" "\$@"
EOS

cat >vendor/pconfigure/Configfile <<EOS
LANGUAGES += bash
BINARIES  += pconfigure
SOURCES   += pconfigure.bash
EOS

cat >vendor/pconfigure/bootstrap.sh <<EOS
#!/bin/bash -e
mkdir -p bin
{ echo "#!/bin/bash"; cat src/pconfigure.bash; } > bin/pconfigure
chmod +x bin/pconfigure
echo "# bootstrapped" > Makefile
EOS
chmod +x vendor/pconfigure/bootstrap.sh

cat >Configfile <<'CONFIGFILE'
BOOTSTRAP       = vendor/pconfigure
SUBPROJECTS    += wrap
CONFIG         += probe
CONFIGFILE

cat >Configfiles/probe <<'PROBE'
#!/bin/bash
echo "CONFIG_DEPS += wrap/obj/tree/build/bin/tool"
if test -e wrap/obj/tree/build/bin/tool
then
    echo "PHONY += tool-found"
else
    echo "PHONY += tool-missing"
fi
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

cat >tree/Makefile <<'MAKEFILE'
O ?= $(CURDIR)/build

all: $(O)/.config
	@mkdir -p $(O)/bin
	@echo tool > $(O)/bin/tool

tiny_defconfig:
	@mkdir -p $(O)
	@cp $(CURDIR)/configs/tiny_defconfig $(O)/.config
MAKEFILE

$PTEST_BINARY $PCONFIGURE_ARGS
grep '^Makefile.pconfigure:' Makefile.pconfigure
grep -q 'tool-missing' Makefile.pconfigure

# Bare, so that make has the tree's rule for it.
grep -q '^Makefile.pconfigure:.* wrap/obj/tree/build/bin/tool' Makefile.pconfigure
if grep -q '\$(wildcard wrap/obj/tree/build/bin/tool)' Makefile.pconfigure
then
    exit 1
fi

# One make: the tool is built, the committed Makefile's recipe
# reconfigures, and what comes out found the tool.
make $MAKE_ARGS > first.log 2>&1 || { cat first.log; exit 1; }
cat first.log
test -e wrap/obj/tree/build/bin/tool
grep -q 'tool-found' Makefile.pconfigure
if grep -q 'tool-missing' Makefile.pconfigure
then
    exit 1
fi
