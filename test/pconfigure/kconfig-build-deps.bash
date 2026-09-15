#include "harness_start.bash"
#pconfigure TESTDEPS += bin/psubdeps

# The same argument as kconfig-deps.bash, one step further along.  A
# guess made from the outside is bad at finding what a tree's
# CONFIGURATION read, and it is far worse at finding what its BUILD
# read: it finds the files that get compiled and almost none of the
# ones that get included.  A kbuild tree writes that down as it goes,
# beside every object it compiles.
#
# "hostinc/secret.h" is the whole test.  It sits outside the vendored
# tree altogether -- the tree reads it because a MAKEOPS put its
# directory on the compiler's include path, which is exactly how this
# project hands a kernel its host headers.  A guess made by walking
# the tree cannot reach out of the tree; the tree says it read it.

mkdir -p src hostinc sub/configs sub/include sub/kernel

cat >Configfile <<EOF
BUILD_SYSTEMS += kconfig

SUBPROJECTS   += sub
CONFIGUREOPTS += --defconfig tiny_defconfig
MAKEOPS       += HOSTINC=\$(abspath hostinc)

LANGUAGES   += c
BINARIES    += test
SOURCES     += test.c
EOF

cat >src/test.c <<EOF
int main(void) { return 0; }
EOF

cat >sub/Kconfig <<'EOF'
config BASE
	bool "base"
	default y
EOF

cat >sub/configs/tiny_defconfig <<'EOF'
CONFIG_BASE=y
EOF

cat >sub/kernel/thing.c <<'EOF'
int thing(void) { return 0; }
EOF

echo "/* seen from outside */" > sub/include/visible.h

# Reachable only by asking the tree.
echo "/* nothing names me */" > hostinc/secret.h

# The vendored build system.  Configuring writes what the
# configuration read, the way kbuild does; building writes what the
# compile read, the way kbuild does -- one file beside the object,
# with the paths absolute and the config stamps named through a
# $(wildcard) they are allowed not to satisfy.
cat >sub/Makefile <<'EOF'
O ?= $(CURDIR)/build

all: $(O)/.config
	@mkdir -p $(O)/kernel
	@{ printf 'savedcmd_kernel/thing.o := cc -c -o kernel/thing.o\n\n'; \
	   printf 'source_kernel/thing.o := %s/kernel/thing.c\n\n' '$(CURDIR)'; \
	   printf 'deps_kernel/thing.o := \\\n'; \
	   test -e "$(CURDIR)/include/visible.h" && \
	     printf '  %s/include/visible.h \\\n' '$(CURDIR)'; \
	   test -e "$(HOSTINC)/secret.h" && \
	     printf '  %s/secret.h \\\n' '$(HOSTINC)'; \
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

##############################################################################
# What the Makefile says before anything has been built                      #
##############################################################################
# A second fragment, hung off the build stamp rather than off the
# configuration, and with a context of its own.  Two questions, two
# files: the cheap answer's rule does not pay for the expensive one,
# which for a real kernel is a walk of ten thousand files.
grep -q "^include obj/sub/build-deps.mk$" Makefile

# It names psubdeps for the same reason its cheaper sibling does, and
# that is asserted here as well rather than left to kconfig-deps.bash,
# because these are two rules written from two places and closing the
# hole in one of them is how it comes back.  See kconfig-deps.bash for
# why the "$" on the end of this pattern is the assertion, why the
# leading "/" in front of the tool is what makes the absolute spelling
# the thing being pinned, and why the pattern is in single quotes
# rather than double ones -- the double-quoted spelling was wrong in
# both of these to begin with, and it was wrong silently.
grep -q '^obj/sub/build-deps.mk: obj/sub/build-deps-context \$(wildcard /[^ )]*/psubdeps)$' Makefile
test -e obj/sub/build-deps-context

# And the guess has not got the hidden header, which is the point.
if grep "^obj/sub/build-stamp:" Makefile | grep -q "secret"
then
    exit 1
fi

##############################################################################
# One build                                                                  #
##############################################################################
make $MAKE_ARGS > build.log 2>&1
cat build.log

# The tree has been built, so it has said what it read, so the
# fragment says it too -- all in the one make, because the recipe asks
# again on its way past.
cat obj/sub/build-deps.mk
grep -q "^obj/sub/build-stamp:.* hostinc/secret.h" obj/sub/build-deps.mk
grep -q "^obj/sub/build-stamp:.* sub/include/visible.h" obj/sub/build-deps.mk
grep -q "^obj/sub/build-stamp:.* sub/kernel/thing.c" obj/sub/build-deps.mk
grep -q "^hostinc/secret.h:$" obj/sub/build-deps.mk

# A config stamp the tree keeps for itself is decided by the .config
# this rule already waits on, so it is not a prerequisite.
if grep -q "wildcard\|include/config/FOO" obj/sub/build-deps.mk
then
    exit 1
fi

##############################################################################
# A second make                                                              #
##############################################################################
# Which does nothing.  A fragment written by a rule the build runs is
# a fragment that could keep making itself out of date, so this is the
# assertion that says it does not.
make $MAKE_ARGS > second.log 2>&1
cat second.log
grep -q "Nothing to be done" second.log

##############################################################################
# A header only the tree knew about                                          #
##############################################################################
# The whole point.  Editing this used to change nothing, because
# nothing outside the tree had ever heard of it.
sleep 1
touch hostinc/secret.h

make $MAKE_ARGS > third.log 2>&1
cat third.log
grep -q "MAKE" third.log

# And it settles again.
make $MAKE_ARGS > fourth.log 2>&1
cat fourth.log
grep -q "Nothing to be done" fourth.log

##############################################################################
# A header only the tree knew about, deleted                                 #
##############################################################################
# Each path gets a rule with nothing in it, so a header that has gone
# away is a reason to build the tree again rather than a build that
# stops on a prerequisite nothing knows how to make.
sleep 1
rm hostinc/secret.h

make $MAKE_ARGS > fifth.log 2>&1
cat fifth.log
grep -q "MAKE" fifth.log

# The tree, asked again, no longer says it read it.
if grep -q "secret" obj/sub/build-deps.mk
then
    exit 1
fi

make $MAKE_ARGS > sixth.log 2>&1
cat sixth.log
grep -q "Nothing to be done" sixth.log

exit 0
