#include "harness_start.bash"

# CONFIG_DEPS on a file a vendored tree in the same build installs.
#
# The case is a Configfile that asks a tool for its answer -- an
# llvm-config for LLVM's flags -- where the tool is one the build
# itself vendors.  The first configure of a fresh tree runs before the
# tool exists, so the Configfile finds nothing in the tree and settles
# for whatever else it can find.  A CONFIG_DEPS on the tool is what
# says "ask again once it's there", and from the second build on it
# does more than that: the name has a rule behind it, so make builds
# the tool before it decides whether to reconfigure, and the
# configuration never sees a stale answer.
#
# On a fresh tree the $(wildcard) every other watched name goes
# through expanded to nothing, so that ordering was missing from
# exactly the build that needed it most: the first make configured
# against the wrong tool, built against it, and only the make after
# the tool landed got it right.  A name some vendored tree's
# SUBPROJECT_TARGETS produces is written bare instead, and the first
# make builds the tool, reconfigures, and carries on with the answer
# the Configfile would have given all along.

# The rule runs whatever the PATH calls "pconfigure", the same as
# "make reconfigure" does, so the PATH is what has to be pointed at
# the one under test.
export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p wrap tree/configs Configfiles

# The vendored tree sits under a wrapper project of its own, the way a
# tree with a build system of its own usually gets pulled in, so the
# name the probe watches is one that reaches into somebody else's
# object directory.
cat >Configfile <<'CONFIGFILE'
AUTORECONFIGURE = true
SUBPROJECTS    += wrap
CONFIG         += probe
CONFIGFILE

# The probe watches the vendored tool and says whether it found it,
# which is what the assertions read back out of the Makefile.
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
grep '^Makefile:' Makefile

# The fresh configure couldn't see the tool, and said so.
grep -q 'tool-missing' Makefile

# The vendored tool is a plain prerequisite of the reconfigure rule,
# not one hidden behind a $(wildcard) that expands to nothing until
# somebody else happens to build it.
grep -q '^Makefile:.* wrap/obj/tree/build/bin/tool' Makefile
if grep -q '\$(wildcard wrap/obj/tree/build/bin/tool)' Makefile
then
    exit 1
fi

# One make: the tool is built first, the probe asked again, and the
# Makefile the rest of the build ran under is the one that found it.
make $MAKE_ARGS > first.log 2>&1 || { cat first.log; exit 1; }
cat first.log
grep -q "^PCONFIGURE$" first.log
grep -q 'tool-found' Makefile
if grep -q 'tool-missing' Makefile
then
    exit 1
fi

# And a second make settles: the reconfigure wrote this Makefile after
# the tool was built, so nothing it watches is newer than it any more.
make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
if grep -q "^PCONFIGURE$" second.log
then
    exit 1
fi

# A binary this build links stays behind the $(wildcard), and that is
# the line between the two rather than an accident of which was tried.
# Its link line comes out of pdeps fragments, and make remakes the
# Makefile before it has read any -- building it from in there on a
# fresh tree would link it out of nothing.  So that one keeps waiting
# to exist.  A tree of its own, because once it does exist it is a
# CONFIG_DEPS the build rewrites on every link, and the second make
# above would reconfigure for it.
mkdir -p linked/src
cat >linked/Configfile <<'CONFIGFILE'
AUTORECONFIGURE = true
LANGUAGES      += c++
BINARIES       += top
SOURCES        += top.c++
CONFIG_DEPS    += bin/top
CONFIGFILE
cat >linked/src/top.c++ <<'SOURCE'
int main(void) { return 0; }
SOURCE
(cd linked && $PTEST_BINARY $PCONFIGURE_ARGS)
grep -q '\$(wildcard bin/top)' linked/Makefile

exit 0
