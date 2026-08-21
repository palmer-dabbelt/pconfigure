#include "harness_start.bash"

mkdir -p sub/configs sub/scripts/kconfig sub/drivers
mkdir -p bare/configs frags

# Everything below "SUBPROJECTS += sub" is about that one tree, which
# is why the second one gets a SUBPROJECTS of its own with nothing
# after it.  Note the quoted heredoc: "$(abspath tests/x)" is a thing
# make is supposed to work out, so the shell that writes this file has
# to keep its hands off it.
cat >Configfile <<'EOF'
BUILD_SYSTEMS += kconfig

SUBPROJECTS   += sub
CONFIGUREOPTS += --defconfig tiny_defconfig
CONFIGUREOPTS += --make-var MY_VAR=$(abspath tests/x)
CONFIGUREOPTS += --env MY_ENV=fromenv
CONFIGUREOPTS += --merge-config frags/net.config
CONFIGUREOPTS += --configure CONFIG_EXTRA=y
CONFIGUREOPTS += --target sdk
CONFIGUREOPTS += --target all

SUBPROJECTS   += bare
EOF

##############################################################################
# A tree that looks enough like Linux to be worth chasing                    #
##############################################################################
cat >sub/Kconfig <<'EOF'
config BASE
	bool "base"
	default y

source "drivers/Kconfig"
EOF

cat >sub/drivers/Kconfig <<'EOF'
config EXTRA
	bool "extra"

config NET
	bool "net"
EOF

cat >sub/configs/tiny_defconfig <<'EOF'
CONFIG_BASE=y
EOF

# The two values that have to survive the trip get written back out
# where the test can read them: "$$MY_ENV" is the environment the
# recipe runs in, and "$(MY_VAR)" is a variable make was handed on its
# command line.  Asking the tree for them is the only way to tell the
# two apart, since a Makefile that only ever looked at one of them
# would be happy either way.
cat >sub/Makefile <<'EOF'
O ?= $(CURDIR)/build

all: $(O)/.config
	@mkdir -p $(O)
	@cp $(O)/.config $(O)/built.txt
	@echo "MY_ENV=$$MY_ENV" >> $(O)/built.txt
	@echo "MY_VAR=$(MY_VAR)" >> $(O)/built.txt

sdk:
	@mkdir -p $(O)
	@echo "sdk" > $(O)/sdk.txt

tiny_defconfig:
	@mkdir -p $(O)
	@cp $(CURDIR)/configs/tiny_defconfig $(O)/.config

olddefconfig:
	@mkdir -p $(O)
	@echo "# olddefconfig" >> $(O)/.config
EOF

cat >sub/drivers/Makefile <<'EOF'
obj-y += driver.o
EOF

cat >sub/drivers/driver.c <<'EOF'
int driver(void) { return 1; }
EOF

cat >sub/scripts/config <<'EOF'
#!/bin/bash
set -e
file=.config
while [[ "$#" -gt 0 ]]
do
    case "$1" in
    --file)    file="$2";                        shift 2;;
    --enable)  echo "$2=y" >> "$file";           shift 2;;
    --module)  echo "$2=m" >> "$file";           shift 2;;
    --disable) echo "# $2 is not set" >> "$file"; shift 2;;
    --set-val) echo "$2=$3" >> "$file";          shift 3;;
    *)                                            shift 1;;
    esac
done
EOF
chmod +x sub/scripts/config

# A stand-in for the tree's own merge program, which is only ever
# asked to do the one thing pconfigure asks the real one for: take the
# base configuration as its first argument, merge everything after it
# in, and write the answer where KCONFIG_CONFIG says.  It refuses to
# run without "-m" on purpose -- without it the real program runs the
# tree's own make from whatever directory it happens to be in, so
# pconfigure passing it is part of what's being tested.
#
# This is POSIX sh and nothing else.  The real program ends in "cp -T"
# and the real one needs GNU coreutils for it, but what's being tested
# here is the command line pconfigure writes, not which cp is on the
# PATH.
cat >sub/scripts/kconfig/merge_config.sh <<'EOF'
#!/bin/sh
set -e

merge_only=false
out="${KCONFIG_CONFIG:-.config}"
base=
frags=

while [ "$#" -gt 0 ]
do
    case "$1" in
    -m) merge_only=true; shift 1;;
    -O) shift 2;;
    -*) shift 1;;
    *)  if [ -z "$base" ]
        then
            base="$1"
        else
            frags="$frags $1"
        fi
        shift 1;;
    esac
done

if [ "$merge_only" != "true" ]
then
    echo "merge_config.sh: run without -m" 1>&2
    exit 1
fi

if [ "$base" != "$out" ]
then
    cat "$base" > "$out"
fi

for frag in $frags
do
    cat "$frag" >> "$out"
done
EOF
chmod +x sub/scripts/kconfig/merge_config.sh

# The fragment lives outside the vendored tree, because it's this
# project's statement about how it wants somebody else's tree
# configured rather than anything the tree has to say for itself.
cat >frags/net.config <<'EOF'
CONFIG_NET=y
EOF

##############################################################################
# A tree that was asked for nothing at all                                   #
##############################################################################
# The second tree exists to pin down what happens when neither a
# --configure nor a --merge-config was written.  Nothing wrote into
# its .config, so there's nothing for Kconfig to have the last word
# on, and an olddefconfig would be a sub-make run for no reason.
cat >bare/Kconfig <<'EOF'
config BARE
	bool "bare"
	default y
EOF

cat >bare/Makefile <<'EOF'
O ?= $(CURDIR)/build

all: $(O)/.config
	@mkdir -p $(O)
	@cp $(O)/.config $(O)/bare.txt

defconfig:
	@mkdir -p $(O)
	@echo "CONFIG_BARE=y" > $(O)/.config

olddefconfig:
	@mkdir -p $(O)
	@echo "# olddefconfig" >> $(O)/.config
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# The two rules, and the recipes out of each of them.  Pulling the
# recipe out by hand is worth the trouble: most of what's being tested
# here is what order things happen in, and a grep over the whole file
# can't tell "before" from "after".
awk '/^\t/ { if (p) print; next } { p = 0 } /^obj\/kconfig\/sub\/build\/\.config:/ { p = 1 }' Makefile > config.rule
awk '/^\t/ { if (p) print; next } { p = 0 } /^obj\/kconfig\/sub\/build-stamp:/ { p = 1 }' Makefile > stamp.rule
awk '/^\t/ { if (p) print; next } { p = 0 } /^obj\/kconfig\/bare\/build\/\.config:/ { p = 1 }' Makefile > bare.rule
cat config.rule
cat stamp.rule
cat bare.rule

##############################################################################
# --make-var                                                                 #
##############################################################################
# A variable make was handed on its command line beats whatever the
# tree's own Makefile says, which is the whole reason to write one.
# It goes after the "O=" pconfigure insists on, so a tree that has an
# opinion about where its output goes still doesn't get to have it.
grep -q -- '-C sub O=\$(abspath obj/kconfig/sub/build) MY_VAR=\$(abspath tests/x)' Makefile

# The same variable reaches all three sub-makes, because a tree told
# something for the defconfig and not for the build configures for one
# machine and then builds for another.
grep -q -- '-C sub .*MY_VAR=\$(abspath tests/x) tiny_defconfig$' config.rule
grep -q -- '-C sub .*MY_VAR=\$(abspath tests/x) olddefconfig$' config.rule
grep -q -- '-C sub .*MY_VAR=\$(abspath tests/x) sdk$' stamp.rule

# What was written is what make is told, character for character.
# Taking the value apart at configure time and putting it back
# together would leave "$(abspath tests/x)" as some path pconfigure
# guessed at, and pconfigure has no business guessing: make is the one
# that knows what directory it'll be run from.
if grep -q 'MY_VAR=/' Makefile
then
    exit 1
fi

##############################################################################
# --env                                                                      #
##############################################################################
# An environment variable and a make command-line variable are not the
# same thing -- the tree's Makefile is allowed to override the first
# and isn't allowed to override the second -- and the only way to say
# which one you meant is where it lands.  This one goes in front of the
# program's name, which is what makes it an environment variable
# rather than another argument.
grep -q '^	@MY_ENV=fromenv \$(MAKE) .*-C sub .*tiny_defconfig$' Makefile
grep -q '^	@MY_ENV=fromenv \$(MAKE) .*-C sub .*olddefconfig$' Makefile
grep -q '^	@MY_ENV=fromenv \$(MAKE) .*-C sub .*sdk$' Makefile
grep -q '^	@MY_ENV=fromenv \$(MAKE) .*-C sub .*all$' Makefile

# It reaches the tree's own programs too, and not just its make: a
# PATH that was set so the merge program can find GNU coreutils is
# useless if it only ever gets set for something else.
grep -q '^	@MY_ENV=fromenv sub/scripts/config --file ' Makefile
grep -q '^	@MY_ENV=fromenv KCONFIG_CONFIG=' Makefile

# And it is never on the far side of $(MAKE), where it would stop
# being an environment variable and start being an override the tree
# can't argue with.
if grep -q '\$(MAKE).*MY_ENV=fromenv' Makefile
then
    exit 1
fi

##############################################################################
# --target                                                                   #
##############################################################################
# One sub-make per target rather than one sub-make with a list of
# goals: "make -j" handed several goals is allowed to run them at the
# same time, and neither kbuild nor anything that copied it survives
# that at the top of the tree.  So the order the targets were written
# in is the order they run in.
grep -q -- '-C sub .* sdk$' stamp.rule
grep -q -- '-C sub .* all$' stamp.rule
grep -n -- '-C sub .* sdk$' stamp.rule | cut -d: -f1 > sdk.at
grep -n -- '-C sub .* all$' stamp.rule | cut -d: -f1 > all.at
test "$(cat sdk.at)" -lt "$(cat all.at)"

# The stamp is still the last thing written, so it means every target
# that was asked for succeeded rather than just the first one.
grep -q '^	@date > \$@$' stamp.rule
test "$(tail -n 1 stamp.rule)" = "	@date > \$@"
grep -q '^all: obj/kconfig/sub/build-stamp$' Makefile

##############################################################################
# --merge-config                                                             #
##############################################################################
# Where the merged configuration lands is said once, in the
# environment.  Saying it with "-O" instead would send the path
# through a readlink only GNU coreutils has, and would say a second
# thing about the output directory on top of the thing it was asked to
# say.
grep -q '^	@MY_ENV=fromenv KCONFIG_CONFIG=obj/kconfig/sub/build/.config sub/scripts/kconfig/merge_config.sh -m obj/kconfig/sub/build/.config frags/net.config$' Makefile

# The fragment is this project's own file, so changing it has to
# reconfigure the tree; and the merge program is the tree's, so a tree
# that gets updated underneath us reconfigures too.  Neither is
# something the Kconfig chase could have found.
grep -q '^obj/kconfig/sub/build/.config:.* frags/net.config' Makefile
grep -q '^obj/kconfig/sub/build/.config:.* sub/scripts/kconfig/merge_config.sh' Makefile

# A fragment is a general statement and a --configure is a specific
# one, so the fragment goes on first and the option gets the last
# word.  The olddefconfig comes after both, because a .config that
# somebody wrote into is one Kconfig hasn't finished with yet.
grep -n 'merge_config.sh' config.rule | cut -d: -f1 > merge.at
grep -n -- '--enable CONFIG_EXTRA' config.rule | cut -d: -f1 > cfg.at
grep -n 'olddefconfig' config.rule | cut -d: -f1 > odc.at
test "$(cat merge.at)" -lt "$(cat cfg.at)"
test "$(cat cfg.at)" -lt "$(cat odc.at)"

##############################################################################
# A tree that was asked for nothing                                          #
##############################################################################
# The olddefconfig used to be written from inside the block that
# handles --configure, and moving it out so a --merge-config could ask
# for it too is exactly the sort of change that leaves it being asked
# for by nobody.  A tree that was handed neither doesn't get one.
grep -q '^obj/kconfig/bare/build/.config:' Makefile
test -s bare.rule
if grep -q 'olddefconfig' bare.rule
then
    exit 1
fi

# Nothing that was said about the first tree leaked onto the second
# one, either: CONFIGUREOPTS land on the subproject the SUBPROJECTS
# above them named and on nothing else.
if grep -q 'MY_ENV' bare.rule
then
    exit 1
fi
if grep -q 'MY_VAR' bare.rule
then
    exit 1
fi

##############################################################################
# Building                                                                   #
##############################################################################
make $MAKE_ARGS

# The defconfig, then the fragment, then the option, then Kconfig's
# last word -- in that order, in one file.
grep -q '^CONFIG_BASE=y$' obj/kconfig/sub/build/.config
grep -q '^CONFIG_NET=y$' obj/kconfig/sub/build/.config
grep -q '^CONFIG_EXTRA=y$' obj/kconfig/sub/build/.config
grep -q '^# olddefconfig$' obj/kconfig/sub/build/.config

# The extra target really was asked for, and so was the default one:
# naming targets replaces what the tree does on its own rather than
# adding to it, so both had to be written out.
test -f obj/kconfig/sub/build/sdk.txt
test -f obj/kconfig/sub/build/built.txt
test -f obj/kconfig/sub/build-stamp

# What the tree saw.  The environment variable arrived as an
# environment variable and the make variable arrived on make's command
# line, and the "$(abspath ...)" was worked out by make rather than by
# pconfigure -- which is what an absolute path here proves, since
# pconfigure never wrote one.
grep -q '^MY_ENV=fromenv$' obj/kconfig/sub/build/built.txt
grep -q '^MY_VAR=/.*/tests/x$' obj/kconfig/sub/build/built.txt

# The tree that asked for nothing built anyway.
test -f obj/kconfig/bare/build/bare.txt

# Nothing was written inside either vendored tree.
test ! -e sub/obj
test ! -e sub/build
test ! -e bare/obj
test ! -e bare/build

##############################################################################
# Rebuilding                                                                 #
##############################################################################
# A second make in a tree that's already built doesn't recurse at all.
# Everything above added prerequisites to these rules, and a
# prerequisite that make can't find a reason to rebuild from is a
# prerequisite that rebuilds every time.
make $MAKE_ARGS > second.out
if grep -q "MAKE" second.out
then
    exit 1
fi
if grep -q "KCONFIG" second.out
then
    exit 1
fi

# Touching the fragment reconfigures the tree it was merged into, and
# only that tree.  This is the edge that nothing could have been
# inferred from: the fragment sits outside the vendored tree, so no
# amount of chasing Kconfigs would ever have found it.
sleep 2s
touch frags/net.config
make $MAKE_ARGS > third.out
grep -q 'KCONFIG.*sub' third.out
grep -q 'MAKE.*sub' third.out
if grep -q 'KCONFIG.*bare' third.out
then
    exit 1
fi

# The reconfiguration ran the whole recipe again rather than picking
# up where it left off, so the fragment is in the new .config too.
grep -q '^CONFIG_NET=y$' obj/kconfig/sub/build/.config
grep -q '^CONFIG_EXTRA=y$' obj/kconfig/sub/build/.config

# Touching the merge program does the same thing, since a tree whose
# own tools changed is a tree whose .config might come out different.
sleep 2s
touch sub/scripts/kconfig/merge_config.sh
make $MAKE_ARGS > fourth.out
grep -q 'KCONFIG.*sub' fourth.out

exit 0
