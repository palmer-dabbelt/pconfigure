#include "harness_start.bash"
#pconfigure TESTDEPS += bin/psubdeps

# A vendored tree built through BUILD_SYSTEMS sits behind a boundary
# the parent build cannot see into -- except that pconfigure's shape
# leaks the boundary on purpose: the tree's own build writes down what
# its objects read, and psubdeps turns those records into fragments
# the next plain make adopts (taxonomy types 8 and G).  kconfig-deps
# and kconfig-build-deps pin the *initial* report; this is the
# incremental case the taxonomy flagged untested, and it is the shape
# of the real-world failure being chased -- a tree whose inputs
# changed behind a boundary, with a parent build that has to find out
# on the next plain make rather than at the next configure.
#
# The tree reads a host header only when its configuration says so.
# Toggling the config -- a file in the vendored tree, not a Configfile
# of the parent -- re-runs the tree's own two steps, the tree reports
# the new dep, and the adopted fragment grows the edge.  No
# reconfigure of the parent happens, and none should: the parent's
# Configfiles did not move; what moved is what the tree reported.

mkdir -p src hostinc sub/configs sub/include sub/kernel

# "-P" so this matches the "root" kconfig.c++ writes into the build
# context, which comes from getcwd() and is therefore already resolved
# past any symlink -- $PTEST_TMPDIR sits under one on a Mac, where
# "/tmp" is a link to "/private/tmp", and the two spellings of the
# same directory would make hostinc/extra.h look unreachable from
# "root" below.
cat >Configfile <<EOF
BUILD_SYSTEMS += kconfig

SUBPROJECTS   += sub
CONFIGUREOPTS += --defconfig tiny_defconfig
MAKEOPS       += HOSTINC=$(pwd -P)/hostinc

LANGUAGES   += c
BINARIES    += test
SOURCES     += test.c
EOF

cat >src/test.c <<'EOF'
int main(void) { return 0; }
EOF

cat >sub/Kconfig <<'EOF'
config BASE
	bool "base"
	default y

config EXTRA
	bool "extra"
EOF

cat >sub/configs/tiny_defconfig <<'EOF'
CONFIG_BASE=y
EOF

cat >sub/kernel/thing.c <<'EOF'
int thing(void) { return 0; }
EOF

echo "/* visible */" > sub/include/visible.h
echo "/* extra dep */" > hostinc/extra.h

cat >sub/Makefile <<'EOF'
HOSTINC ?= hostinc
O ?= $(CURDIR)/build

all: $(O)/.config
	@mkdir -p $(O)/kernel
	@{ printf 'savedcmd_kernel/thing.o := cc -c -o kernel/thing.o\n\n'; \
	   printf 'source_kernel/thing.o := %s/kernel/thing.c\n\n' '$(CURDIR)'; \
	   printf 'deps_kernel/thing.o := \\\n'; \
	   test -e "$(CURDIR)/include/visible.h" && \
	     printf '  %s/include/visible.h \\\n' '$(CURDIR)'; \
	   grep -q '^CONFIG_EXTRA=y' $(O)/.config && \
	     printf '  %s/extra.h \\\n' '$(HOSTINC)'; \
	   printf '    $$(wildcard include/config/FOO) \\\n'; \
	   printf '\n'; \
	   printf '$$(deps_kernel/thing.o):\n'; } > $(O)/kernel/.thing.o.cmd
	@cp $(O)/.config $(O)/built.txt

tiny_defconfig:
	@mkdir -p $(O) $(O)/include/config
	@cp $(CURDIR)/configs/tiny_defconfig $(O)/.config
	@{ printf 'autoconfig := include/config/auto.conf\n\ndeps_config := \\\n'; printf '\tKconfig \\\n'; printf '\n$$(deps_config): ;\n'; } > $(O)/include/config/auto.conf.cmd
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS > first.out 2>&1
cat first.out

# The first build's report: the visible header is on the record, the
# not-yet-enabled one is not.
grep -q "^obj/sub/build-stamp:.* sub/include/visible.h" obj/sub/build-deps.mk
if grep -q "^obj/sub/build-stamp:.* hostinc/extra.h" obj/sub/build-deps.mk
then
    exit 1
fi

make $MAKE_ARGS > settled.out 2>&1
cat settled.out
grep -q "Nothing to be done" settled.out

##############################################################################
# The config toggles, and the tree starts reading the new file               #
##############################################################################
sleep 2
cat >sub/configs/tiny_defconfig <<'EOF'
CONFIG_BASE=y
CONFIG_EXTRA=y
EOF

make $MAKE_ARGS > second.out 2>&1
cat second.out

# The tree re-ran its own steps -- the KCONFIG configure step and the
# MAKE build step -- and no pconfigure ran in the parent: the parent's
# Configfiles never moved.
grep -q "^KCONFIG	sub$" second.out
grep -q "^MAKE	sub$" second.out
if grep -q "^PCONFIGURE$" second.out
then
    exit 1
fi

# The next plain make adopted the new record: the dep the tree just
# started reading is on the stamp's prerequisite line, which is the
# edge a later edit to the file will ride.
grep -q "^obj/sub/build-stamp:.* hostinc/extra.h" obj/sub/build-deps.mk

# And the build settles.
make $MAKE_ARGS > third.out 2>&1
cat third.out
grep -q "Nothing to be done" third.out

exit 0
