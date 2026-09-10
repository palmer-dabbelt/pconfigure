#include "harness_start.bash"
#pconfigure TESTDEPS += bin/psubdeps

# psubdeps on its own, with a context file and a vendored dependency
# file written by hand rather than by a build.  What it does is read
# what a vendored tree said it read and turn that into prerequisites,
# so the two ends of it are both files -- which makes it testable
# without configuring or building a kernel.

psubdeps="$(dirname "$PTEST_BINARY")/psubdeps"

mkdir -p src/vendor/arch obj/vendor/build

context() {
    cat >obj/vendor/deps-context <<EOF
tree src/vendor
output obj/vendor
target obj/vendor/build/.config
fragment obj/vendor/config-deps.mk
dep-file obj/vendor/build/include/config/auto.conf.cmd
dep-file obj/vendor/build/..config.tmp
dep-root src/vendor/
EOF
}

for f in Kconfig arch/Kconfig.arm arch/Kconfig.x86
do
    echo "config X" > "src/vendor/$f"
done

##############################################################################
# Nothing has been built yet                                                 #
##############################################################################
# Every clean checkout starts here: the tree writes its answer while
# it is being configured, so before the first build there is no answer
# to read.  That is an ordinary state and has to come back as a
# fragment saying so, because make is including this file and a
# failure here stops the build before it can produce the very thing
# that would fix it.
context
$psubdeps --context obj/vendor/deps-context
cat obj/vendor/config-deps.mk

grep -q "has not been configured yet" obj/vendor/config-deps.mk
if grep -q "^obj/vendor/build/.config:" obj/vendor/config-deps.mk
then
    exit 1
fi

##############################################################################
# What a kbuild tree writes                                                  #
##############################################################################
# A backslash on every line including the last, and a blank line to
# end the list.  Everything around it belongs to the vendored tree's
# own build and is none of this program's business -- which is most of
# the file, so ignoring it is most of the parsing.
mkdir -p obj/vendor/build/include/config
cat >obj/vendor/build/include/config/auto.conf.cmd <<'DEPFILE'
autoconfig := include/config/auto.conf

deps_config := \
	Kconfig \
	arch/Kconfig.arm \
	arch/Kconfig.x86 \

ifneq "$(ARCH)" "arm64"
include/config/auto.conf: FORCE
endif

$(deps_config): ;
DEPFILE

$psubdeps --context obj/vendor/deps-context
cat obj/vendor/config-deps.mk

# The paths, rooted where the tree's own build spells them from.
grep -q "^obj/vendor/build/.config: src/vendor/Kconfig src/vendor/arch/Kconfig.arm src/vendor/arch/Kconfig.x86$" obj/vendor/config-deps.mk

# And a rule with nothing in it for each, so that one of them being
# deleted is a reason to configure the tree again rather than a build
# that stops on a file nothing knows how to make.
grep -q "^src/vendor/Kconfig:$" obj/vendor/config-deps.mk
grep -q "^src/vendor/arch/Kconfig.arm:$" obj/vendor/config-deps.mk

# Nothing else in the file came through.
if grep -q "autoconfig\|ifneq\|FORCE\|deps_config" obj/vendor/config-deps.mk
then
    exit 1
fi

##############################################################################
# What buildroot writes                                                      #
##############################################################################
# The same list from an older writer, which leaves the backslash off
# the last entry -- so the list ends because a line does not continue
# rather than because the next one is blank.  It also goes by another
# name, which is why the context file names more than one.
rm obj/vendor/build/include/config/auto.conf.cmd
cat >obj/vendor/build/..config.tmp <<'DEPFILE'
deps_config := \
	Kconfig \
	arch/Kconfig.arm \
	arch/Kconfig.x86
ifneq "$(BR2)" "y"
auto.conf: FORCE
endif

$(deps_config): ;
DEPFILE

$psubdeps --context obj/vendor/deps-context
cat obj/vendor/config-deps.mk

grep -q "^obj/vendor/build/.config: src/vendor/Kconfig src/vendor/arch/Kconfig.arm src/vendor/arch/Kconfig.x86$" obj/vendor/config-deps.mk
grep -q "Read out of obj/vendor/build/..config.tmp" obj/vendor/config-deps.mk

##############################################################################
# Paths that mean nothing from here                                          #
##############################################################################
# A tree is allowed to say it read a file this build has no business
# naming.  An absolute path names nothing on anybody else's machine;
# one that climbs out above where make runs names nothing either; and
# a file the tree writes into its own output directory is a clock
# rather than a dependency -- buildroot rewrites its .br2-external.in.*
# every single time make runs, so a rule waiting on one is a rule that
# is never up to date again.
#
# A path that merely leaves the vendored tree is kept: it still lands
# somewhere in this build, and a tree that reads its neighbour has to
# be reconfigured when the neighbour changes.
#
# The generated one is named the way the tree names it, which is from
# inside the output directory rather than from here.
echo "generated" > obj/vendor/build/.br2-external.in.menus
cat >obj/vendor/build/..config.tmp <<'DEPFILE'
deps_config := \
	/etc/somewhere/Kconfig \
	../../../outside/Kconfig \
	../../obj/vendor/build/.br2-external.in.menus \
	Kconfig
DEPFILE

$psubdeps --context obj/vendor/deps-context
cat obj/vendor/config-deps.mk

grep -q "^obj/vendor/build/.config: src/vendor/Kconfig$" obj/vendor/config-deps.mk
grep -q "3 path(s) it named are not reachable" obj/vendor/config-deps.mk
if grep -q "br2-external\|/etc/somewhere\|outside" obj/vendor/config-deps.mk
then
    exit 1
fi

##############################################################################
# A context file it doesn't understand                                       #
##############################################################################
# Written by a pconfigure that knew about something this one doesn't,
# which means the two disagree about what the build is.  Guessing
# which half is right is how a tree ends up half configured.
echo "sideways yes" >> obj/vendor/deps-context
if $psubdeps --context obj/vendor/deps-context > bad.out 2>&1
then
    exit 1
fi
cat bad.out
grep -q "'sideways' in" bad.out

exit 0
