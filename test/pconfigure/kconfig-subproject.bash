#include "harness_start.bash"
#pconfigure TESTDEPS += bin/psubdeps

# A vendored kbuild tree that belongs to a subproject rather than to
# the project at the top of the run.
#
# What a vendored tree read is worked out during the build rather than
# by pconfigure, so the answer lands in a file that a configure writes
# and a build reads: a context saying what to ask, and a fragment
# holding what it said.  Both are full of paths, and a tree configured
# from two places is a tree described by two runs standing different
# distances away from it -- "psub/vendor/Kconfig" from the top and
# "vendor/Kconfig" from inside the subproject.
#
# One name for both would make them one file, and one file cannot hold
# both answers.  Whichever configure ran last would be the one whose
# paths were there, and the other build would include a fragment
# measured from a place it is not standing -- which is a prerequisite
# make has no rule for, reached while it is still reading makefiles,
# so it stops before it builds anything at all.
mkdir -p src psub/src psub/vendor/configs

cat >Configfile <<EOF
LANGUAGES   += c
SUBPROJECTS += psub

BINARIES    += top
SOURCES     += top.c
EOF

cat >src/top.c <<'EOF'
int main(void) { return 0; }
EOF

cat >psub/Configfile <<EOF
BUILD_SYSTEMS += kconfig
SUBPROJECTS   += vendor
CONFIGUREOPTS += --defconfig tiny_defconfig

LANGUAGES += c
BINARIES  += psubbin
SOURCES   += psubbin.c
EOF

cat >psub/src/psubbin.c <<'EOF'
int main(void) { return 0; }
EOF

cat >psub/vendor/Kconfig <<'EOF'
config BASE
	bool "base"
	default y
EOF

cat >psub/vendor/configs/tiny_defconfig <<'EOF'
CONFIG_BASE=y
EOF

# The vendored build system, which writes down what it read the way
# kbuild does: an assignment, one path a line, a backslash on the end.
cat >psub/vendor/Makefile <<'EOF'
O ?= $(CURDIR)/build

all: $(O)/.config
	@mkdir -p $(O)
	@cp $(O)/.config $(O)/built.txt

tiny_defconfig:
	@mkdir -p $(O) $(O)/include/config
	@cp $(CURDIR)/configs/tiny_defconfig $(O)/.config
	@{ printf 'autoconfig := include/config/auto.conf\n\ndeps_config := \\\n'; printf '\t%s \\\n' Kconfig; printf '\n$$(deps_config): ;\n'; } > $(O)/include/config/auto.conf.cmd
EOF

##############################################################################
# Configured from the top                                                    #
##############################################################################
$PTEST_BINARY $PCONFIGURE_ARGS

# Named for the project the tree belongs to, which is the subproject
# rather than the run: "psub" is where it sits as the run that wrote
# it sees things.
test -f psub/obj/vendor/config-deps-context.psub
test -f psub/obj/vendor/build-deps-context.psub

# And the name is not the one a run standing in the subproject would
# use.  Asserted before either of them exists, so that the count below
# is about this run and not about what was already lying around.
test ! -e psub/obj/vendor/config-deps-context
test ! -e psub/obj/vendor/build-deps-context

make $MAKE_ARGS
./bin/top
./psub/bin/psubbin

# What the build wrote into it: the tree's own answer about which
# Kconfig it read, spelled through the variable that says where this
# project is, because from up here that is what reaches the file.
grep -q "^\$(pconfigure_subdir_psub)obj/vendor/build/.config: \$(pconfigure_subdir_psub)vendor/Kconfig\$" \
    psub/obj/vendor/config-deps.psub.mk

cp psub/obj/vendor/config-deps.psub.mk from-the-top.mk
cp psub/obj/vendor/build-deps.psub.mk from-the-top-build.mk

##############################################################################
# ... and configured again from inside the subproject                        #
##############################################################################
(cd psub && $PTEST_BINARY $PCONFIGURE_ARGS)
(cd psub && make $MAKE_ARGS && ./bin/psubbin)

# A second pair, under the name a run standing down there uses, which
# is no name at all: from in there this project has no directory to be
# found through.
test -f psub/obj/vendor/config-deps-context
test -f psub/obj/vendor/build-deps-context

# Saying the same thing measured from where that build was standing.
grep -q "^obj/vendor/build/.config: vendor/Kconfig\$" \
    psub/obj/vendor/config-deps.mk

# And the first pair untouched, which is the whole of what the names
# buy.  A build that rewrote these would not be wrong about anything
# it was doing; it would be wrong about what the other build reads.
cmp from-the-top.mk psub/obj/vendor/config-deps.psub.mk
cmp from-the-top-build.mk psub/obj/vendor/build-deps.psub.mk

##############################################################################
# ... and the top still builds                                               #
##############################################################################
# Which is where it stopped before: the fragment the top includes is
# resolved while make is still reading makefiles, so a path in it that
# means nothing from up here stops the build before it starts, whether
# or not there was any work to do.
make $MAKE_ARGS
./bin/top
./psub/bin/psubbin

exit 0
