#include "harness_start.bash"
#pconfigure TESTDEPS += bin/psubdeps

# The other half of psubdeps: what a vendored tree read while it was
# BUILDING, rather than while it was being configured.  A kbuild tree
# writes that down a piece at a time, in a file beside every object it
# compiles, so the input here is a directory rather than a file -- but
# the shape of what is in it is the same, and so is everything this
# does with it.

psubdeps="$(dirname "$PTEST_BINARY")/psubdeps"
root="$(pwd)"

mkdir -p src/vendor/kernel src/vendor/include obj/vendor/build/kernel

context() {
    cat >obj/vendor/build-deps-context <<EOF
tree src/vendor
output obj/vendor
target obj/vendor/build-stamp
fragment obj/vendor/build-deps.mk
cmd-root obj/vendor/build
root $root
EOF
}

##############################################################################
# Nothing has been built yet                                                 #
##############################################################################
# A tree writes these while it compiles, so before the first build
# there are none of them.  make is including this file, so a failure
# here would stop the build that was about to produce the very thing
# that answers the question.
context
$psubdeps --context obj/vendor/build-deps-context
cat obj/vendor/build-deps.mk

grep -q "has not been built yet" obj/vendor/build-deps.mk
if grep -q "^obj/vendor/build-stamp:" obj/vendor/build-deps.mk
then
    exit 1
fi

##############################################################################
# What a kbuild tree leaves beside an object                                 #
##############################################################################
# The source it compiled on one line, the headers it read in a list,
# and a great deal of command line that is none of this program's
# business.  Three of the entries are deliberately not prerequisites:
# a config stamp the tree keeps for itself, a header the tree
# generated into its own output directory, and a system header from
# somewhere this build has never heard of.
cat >obj/vendor/build/kernel/.thing.o.cmd <<EOF
savedcmd_kernel/thing.o := cc -Wp,-MMD,kernel/.thing.o.d -c -o kernel/thing.o $root/src/vendor/kernel/thing.c

source_kernel/thing.o := $root/src/vendor/kernel/thing.c

deps_kernel/thing.o := \\
  $root/src/vendor/include/one.h \\
    \$(wildcard include/config/FOO) \\
  $root/src/vendor/include/two.h \\
    \$(wildcard include/config/BAR) \\
  include/generated/autoconf.h \\
  /opt/elsewhere/system.h \\

\$(deps_kernel/thing.o):
EOF

$psubdeps --context obj/vendor/build-deps-context
cat obj/vendor/build-deps.mk

grep -q "^obj/vendor/build-stamp:.* src/vendor/include/one.h" obj/vendor/build-deps.mk
grep -q "^obj/vendor/build-stamp:.* src/vendor/include/two.h" obj/vendor/build-deps.mk
grep -q "^obj/vendor/build-stamp:.* src/vendor/kernel/thing.c" obj/vendor/build-deps.mk

# A file that has gone away since is a reason to build the tree again
# rather than a reason for make to refuse to build anything at all.
grep -q "^src/vendor/include/one.h:$" obj/vendor/build-deps.mk

# The three that are not prerequisites, each for its own reason.
if grep -q "wildcard\|include/config/FOO" obj/vendor/build-deps.mk
then
    exit 1
fi
if grep -q "obj/vendor/build/include/generated/autoconf.h" obj/vendor/build-deps.mk
then
    exit 1
fi
if grep -q "/opt/elsewhere/system.h" obj/vendor/build-deps.mk
then
    exit 1
fi

##############################################################################
# More than one object                                                       #
##############################################################################
# There is one of these per object and they overlap almost entirely,
# which is the whole reason the answer is worth collecting: what comes
# out is the union, said once.
mkdir -p obj/vendor/build/mm
cat >obj/vendor/build/mm/.other.o.cmd <<EOF
source_mm/other.o := $root/src/vendor/mm/other.c

deps_mm/other.o := \\
  $root/src/vendor/include/one.h \\
  $root/src/vendor/include/three.h \\

EOF

$psubdeps --context obj/vendor/build-deps-context
cat obj/vendor/build-deps.mk

grep -q "^obj/vendor/build-stamp:.* src/vendor/include/three.h" obj/vendor/build-deps.mk
grep -q "^obj/vendor/build-stamp:.* src/vendor/mm/other.c" obj/vendor/build-deps.mk
test "$(grep -c '^src/vendor/include/one.h:$' obj/vendor/build-deps.mk)" = 1

##############################################################################
# The configuration's own list, which belongs to the other half        #
##############################################################################
# kbuild writes that one into a file of this name too, and its paths
# are relative to the source tree rather than absolute -- so reading
# it here would be doing the wrong arithmetic to a question that is
# already answered properly elsewhere.
mkdir -p obj/vendor/build/include/config
cat >obj/vendor/build/include/config/auto.conf.cmd <<'EOF'
autoconfig := include/config/auto.conf

deps_config := \
	Kconfig \
	arch/arm64/Kconfig \

$(deps_config): ;
EOF

$psubdeps --context obj/vendor/build-deps-context
cat obj/vendor/build-deps.mk

if grep -q "arch/arm64/Kconfig" obj/vendor/build-deps.mk
then
    exit 1
fi

##############################################################################
# A context that cannot say which question it is asking                      #
##############################################################################
# One question per context.  A context that asks both, or neither, was
# written by something that had not decided which -- and picking one
# here would quietly make half a Makefile out of it.
both() {
    if $psubdeps --context obj/vendor/bad > out 2>&1
    then
        exit 1
    fi
    cat out
}

cat >obj/vendor/bad <<EOF
tree src/vendor
target obj/vendor/build-stamp
fragment obj/vendor/bad.mk
cmd-root obj/vendor/build
root $root
dep-file obj/vendor/build/include/config/auto.conf.cmd
EOF
both
grep -q "asks for both" out

cat >obj/vendor/bad <<EOF
tree src/vendor
target obj/vendor/build-stamp
fragment obj/vendor/bad.mk
EOF
both
grep -q "neither 'dep-file' nor 'cmd-root'" out

cat >obj/vendor/bad <<EOF
tree src/vendor
target obj/vendor/build-stamp
fragment obj/vendor/bad.mk
cmd-root obj/vendor/build
EOF
both
grep -q "says 'cmd-root' but no 'root'" out

exit 0
