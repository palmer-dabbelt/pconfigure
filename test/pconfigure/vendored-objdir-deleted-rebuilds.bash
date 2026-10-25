#include "harness_start.bash"

# A vendored tree keeps what pconfigure wrote about it -- the options
# it is configured with, the context its dependency scan reads -- in
# the parent's object directory, beside the tree's own build output.
# Deleting that directory is how somebody throws away a vendored
# build to start it again, and what should come back is a configure
# and a build of the tree.  What comes back instead is "No rule to
# make target" for a file pconfigure wrote and no rule makes.

export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p sub/configs

cat >Configfile <<'EOF'
BUILD_SYSTEMS   += kconfig
SUBPROJECTS     += sub
CONFIGUREOPTS   += --defconfig tiny_defconfig
EOF

cat >sub/Kconfig <<'EOF'
config BASE
	bool "base"
	default y
EOF

cat >sub/configs/tiny_defconfig <<'EOF'
CONFIG_BASE=y
EOF

cat >sub/Makefile <<'EOF'
O ?= $(CURDIR)/build

all: $(O)/.config
	@cp $(O)/.config $(O)/built.txt

tiny_defconfig:
	@mkdir -p $(O)
	@cp $(CURDIR)/configs/tiny_defconfig $(O)/.config
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
built="$(find obj -name built.txt)"
test -n "$built"

rm -rf obj

make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
test -e "$built"

# And it settles, so whatever brought the files back is not something
# every make goes on doing.
make $MAKE_ARGS > settled.log 2>&1 || { cat settled.log; exit 1; }
cat settled.log
grep -q "Nothing to be done" settled.log

exit 0
