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
CONFIGUREOPTS += --env MY_WORDS=two words
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
	@echo "MY_WORDS=$$MY_WORDS" >> $(O)/built.txt
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

##############################################################################
# The fake's refusal, taken on purpose                                       #
##############################################################################
# That "-m" arm is what stands behind every claim below about
# pconfigure passing it, and nothing in the rest of this file ever
# takes it: pconfigure has always written the flag.  An arm no
# scenario reaches is an arm whose typo nobody finds, and a net that
# catches nothing looks exactly like one that works -- so it gets run
# here, once, by hand.
#
# In a directory of its own beside the fixture, so that what this run
# leaves behind is not something a "nothing was written in the tree"
# assertion further down has to reason about.
mkdir -p probe
echo "CONFIG_BASE=y" > probe/base.config
echo "CONFIG_NET=y" > probe/frag.config

if (cd probe && KCONFIG_CONFIG=out.config \
        ../sub/scripts/kconfig/merge_config.sh -O . base.config frag.config) \
    > probe/no-m.out 2>&1
then
    exit 1
fi
grep -q "merge_config.sh: run without -m" probe/no-m.out

# And it wrote nothing on the way out, which is the half of the
# refusal that matters: a program that merged and then complained
# would have left the file this is about.
test ! -e probe/out.config

# The same run with the flag, so that what the arm above refused is
# one flag away from working rather than broken in some other way
# nobody would notice.
(cd probe && KCONFIG_CONFIG=out.config \
    ../sub/scripts/kconfig/merge_config.sh -m -O . base.config frag.config)
grep -q "^CONFIG_BASE=y$" probe/out.config
grep -q "^CONFIG_NET=y$" probe/out.config
rm -rf probe

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
awk '/^\t/ { if (p) print; next } { p = 0 } /^obj\/sub\/build\/\.config:/ { p = 1 }' Makefile > config.rule
awk '/^\t/ { if (p) print; next } { p = 0 } /^obj\/sub\/build-stamp:/ { p = 1 }' Makefile > stamp.rule
awk '/^\t/ { if (p) print; next } { p = 0 } /^obj\/bare\/build\/\.config:/ { p = 1 }' Makefile > bare.rule
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
grep -q -- "-C sub O=\\\$(abspath obj/sub/build) 'MY_VAR=\\\$(abspath tests/x)'" Makefile

# The same variable reaches all three sub-makes, because a tree told
# something for the defconfig and not for the build configures for one
# machine and then builds for another.
grep -q -- "-C sub .*'MY_VAR=\\\$(abspath tests/x)' 'tiny_defconfig'\$" config.rule
grep -q -- "-C sub .*'MY_VAR=\\\$(abspath tests/x)' olddefconfig\$" config.rule
grep -q -- "-C sub .*'MY_VAR=\\\$(abspath tests/x)' 'sdk'\$" stamp.rule

# What was written is what make is told, character for character.
# Taking the value apart at configure time and putting it back
# together would leave "$(abspath tests/x)" as some path pconfigure
# guessed at, and pconfigure has no business guessing: make is the one
# that knows what directory it'll be run from.
if grep -q 'MY_VAR=/' Makefile
then
    exit 1
fi

# The quotes around it are the shell's business rather than make's:
# they keep a value with a space in it one argument, and make has
# already expanded the line by the time the shell reads them.  Without
# them a "KCFLAGS=-O2 -g" reaches make as a variable worth "-O2" and a
# "-g" that make reads as a flag of its own.

##############################################################################
# --env                                                                      #
##############################################################################
# An environment variable and a make command-line variable are not the
# same thing -- the tree's Makefile is allowed to override the first
# and isn't allowed to override the second -- and the only way to say
# which one you meant is where it lands.  This one goes in front of the
# program's name, which is what makes it an environment variable
# rather than another argument.
grep -q "^	@MY_ENV='fromenv' .*\$(MAKE) .*-C sub .*'tiny_defconfig'\$" Makefile
grep -q "^	@MY_ENV='fromenv' .*\$(MAKE) .*-C sub .*olddefconfig\$" Makefile
grep -q "^	@MY_ENV='fromenv' .*\$(MAKE) .*-C sub .*'sdk'\$" Makefile
grep -q "^	@MY_ENV='fromenv' .*\$(MAKE) .*-C sub .*'all'\$" Makefile

# It reaches the tree's own programs too, and not just its make: a
# PATH that was set so the merge program can find GNU coreutils is
# useless if it only ever gets set for something else.
grep -q "^	@MY_ENV='fromenv' .*sub/scripts/config --file " Makefile
grep -q "^	@MY_ENV='fromenv' .*KCONFIG_CONFIG=" Makefile

# The value is quoted and the name is not, which is the only way round
# that works: a shell reads "NAME=VALUE cmd" as an assignment in front
# of a command, while 'NAME=VALUE' quoted whole is the name of a
# program nobody has.  Written without the quotes -- which is how this
# was first written -- the second word of a value with a space in it
# stops being part of the assignment and becomes a command of its own,
# so the recipe dies at build time having been accepted without a
# murmur at configure time.  The value that proves it is the one with
# a space in it, since a value without one looks the same either way.
grep -q "MY_WORDS='two words'" Makefile
if grep -q 'MY_WORDS=two words' Makefile
then
    exit 1
fi

# And it is never on the far side of $(MAKE), where it would stop
# being an environment variable and start being an override the tree
# can't argue with.
if grep -q '\$(MAKE).*MY_ENV=' Makefile
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
grep -q -- "-C sub .* 'sdk'\$" stamp.rule
grep -q -- "-C sub .* 'all'\$" stamp.rule
grep -n -- "-C sub .* 'sdk'\$" stamp.rule | cut -d: -f1 > sdk.at
grep -n -- "-C sub .* 'all'\$" stamp.rule | cut -d: -f1 > all.at
test "$(cat sdk.at)" -lt "$(cat all.at)"

# The stamp is still the last thing written, so it means every target
# that was asked for succeeded rather than just the first one.
grep -q '^	@date > \$@$' stamp.rule
test "$(tail -n 1 stamp.rule)" = "	@date > \$@"
grep -q '^all: obj/sub/build-stamp$' Makefile

##############################################################################
# --merge-config                                                             #
##############################################################################
# Where the merged configuration lands is said once, in the
# environment.  Saying it with "-O" instead would send the path
# through a readlink only GNU coreutils has, and would say a second
# thing about the output directory on top of the thing it was asked to
# say.
# The fragment is quoted where it lands in the recipe, which is what
# every other value a CONFIGUREOPTS wrote gets: a recipe is a shell
# command, and a path that isn't quoted in one is however many words
# the shell decides it is.  It stays bare in the prerequisite list
# above, because a prerequisite is a make word and make has no
# quoting for one.
grep -q "^	@MY_ENV='fromenv' MY_WORDS='two words' KCONFIG_CONFIG=obj/sub/build/.config sub/scripts/kconfig/merge_config.sh -m obj/sub/build/.config 'frags/net.config'\$" Makefile

# The fragment is this project's own file, so changing it has to
# reconfigure the tree; and the merge program is the tree's, so a tree
# that gets updated underneath us reconfigures too.  Neither is
# something the Kconfig chase could have found.
grep -q '^obj/sub/build/.config:.* frags/net.config' Makefile
grep -q '^obj/sub/build/.config:.* sub/scripts/kconfig/merge_config.sh' Makefile

# A fragment is a general statement and a --configure is a specific
# one, so the fragment goes on first and the option gets the last
# word.  The olddefconfig comes after both, because a .config that
# somebody wrote into is one Kconfig hasn't finished with yet.
# The name and the value are each quoted on their way to the tree's
# own program, which is what makes one option one name and one value
# however many characters of shell syntax are in either.  Asserted
# outright as well as counted below, because a grep in a pipeline
# whose answer is empty is a "test: integer expression expected" three
# lines further on rather than a failure anybody can read.
grep -q -- "--enable 'CONFIG_EXTRA'" config.rule

grep -n 'merge_config.sh' config.rule | cut -d: -f1 > merge.at
grep -n -- "--enable 'CONFIG_EXTRA'" config.rule | cut -d: -f1 > cfg.at
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
grep -q '^obj/bare/build/.config:' Makefile
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
grep -q '^CONFIG_BASE=y$' obj/sub/build/.config
grep -q '^CONFIG_NET=y$' obj/sub/build/.config
grep -q '^CONFIG_EXTRA=y$' obj/sub/build/.config
grep -q '^# olddefconfig$' obj/sub/build/.config

# The extra target really was asked for, and so was the default one:
# naming targets replaces what the tree does on its own rather than
# adding to it, so both had to be written out.
test -f obj/sub/build/sdk.txt
test -f obj/sub/build/built.txt
test -f obj/sub/build-stamp

# What the tree saw.  The environment variable arrived as an
# environment variable and the make variable arrived on make's command
# line, and the "$(abspath ...)" was worked out by make rather than by
# pconfigure -- which is what an absolute path here proves, since
# pconfigure never wrote one.
grep -q '^MY_ENV=fromenv$' obj/sub/build/built.txt

# And the one with a space in it arrived whole, rather than as a
# variable worth "two" and a "words" the shell tried to run.
grep -q '^MY_WORDS=two words$' obj/sub/build/built.txt
grep -q '^MY_VAR=/.*/tests/x$' obj/sub/build/built.txt

# The tree that asked for nothing built anyway.
test -f obj/bare/build/bare.txt

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
grep -q '^CONFIG_NET=y$' obj/sub/build/.config
grep -q '^CONFIG_EXTRA=y$' obj/sub/build/.config

# Touching the merge program does the same thing, since a tree whose
# own tools changed is a tree whose .config might come out different.
sleep 2s
touch sub/scripts/kconfig/merge_config.sh
make $MAKE_ARGS > fourth.out
grep -q 'KCONFIG.*sub' fourth.out

cd $tempdir

##############################################################################
# The other spelling of an option, and the spacing round it                  #
##############################################################################
# Every CONFIGUREOPTS above is written "--flag value", and the reader
# that takes an option apart accepts "--flag=value" just as readily.
# Nothing said so.  That reader is one function on build_system now
# rather than one copy per build system, so this is the whole of what
# says the second spelling works anywhere -- which is the arrangement
# hoisting it was for, and is only worth anything if somebody writes
# the test.
#
# The spacing is the same convention seen from the other side: what
# comes back is the value with its leading and trailing whitespace
# gone and any run of spaces inside it collapsed to one, so a
# Configfile lined up into columns means the same thing as one that
# isn't.  That is a decision rather than an accident, and a value with
# two spaces in the middle of it is what tells the two apart.
mkdir -p $tempdir/spelling/sub/configs

cat >$tempdir/spelling/sub/Kconfig <<'EOF'
config BASE
	bool "base"
	default y
EOF

cat >$tempdir/spelling/sub/configs/tiny_defconfig <<'EOF'
CONFIG_BASE=y
EOF

cat >$tempdir/spelling/sub/Makefile <<'EOF'
O ?= $(CURDIR)/build

all: $(O)/.config
	@mkdir -p $(O)
	@cp $(O)/.config $(O)/built.txt
	@echo "SPACED=$(SPACED)" >> $(O)/built.txt
	@echo "LOOSE_ENV=$$LOOSE_ENV" >> $(O)/built.txt

tiny_defconfig:
	@mkdir -p $(O)
	@cp $(CURDIR)/configs/tiny_defconfig $(O)/.config
EOF

cat >$tempdir/spelling/Configfile <<'EOF'
BUILD_SYSTEMS += kconfig

SUBPROJECTS   += sub
CONFIGUREOPTS += --defconfig=tiny_defconfig
CONFIGUREOPTS += --env=EQ_ENV=byequals
CONFIGUREOPTS += --env= LOOSE_ENV=afterthegap
CONFIGUREOPTS += --make-var   SPACED=one   two
EOF

cd $tempdir/spelling
$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# The defconfig written with an '=' is the defconfig, which is the
# plainest thing an option can be asked to be: it names the target the
# tree is configured with, so a value read wrong is a sub-make asked
# for a rule the tree hasn't got.
grep -q -- "-C sub .*tiny_defconfig" Makefile
if grep -q -- "=tiny_defconfig" Makefile
then
    exit 1
fi

# And an '=' in the value as well as after the flag, which is the case
# that says the split is at the first one rather than the last: an
# --env is a NAME=VALUE, so reading it from the wrong end would leave
# the name behind.
grep -q "EQ_ENV='byequals'" Makefile

# The whitespace is cleaned rather than kept.  The run between "one"
# and "two" collapses, which is the Configfile reader's doing before
# ever this gets a look at the line -- it is here because a reader
# that stopped doing it would change what this option means and
# nothing else would say so.
grep -q -- "'SPACED=one two'" Makefile

# And an '=' with a gap after it, which is the shape that has a
# leading space to strip: the reader hands over a line with single
# spaces in it, so a "--flag= value" arrives with the gap still
# sitting in front of the value.  What is asserted here is that the
# option is read at all and that the gap is not in the value -- not
# that the stripping is what put it right, because it isn't: the gap
# would land outside this quoting rather than inside it, where a shell
# ignores it.  The option whose value is quoted whole is where the
# difference shows, and it is pinned where that option is written.
grep -q "LOOSE_ENV='afterthegap'" Makefile

make $MAKE_ARGS > spelling.out
cat spelling.out
cat obj/sub/build/built.txt
grep -q '^SPACED=one two$' obj/sub/build/built.txt

# And the variable really reached the tree, rather than merely having
# been written into a recipe: an --env is the option that is not
# quoted whole -- the name has to stay a name for the shell to read
# the thing as an assignment at all -- so what it is worth is only
# ever what the sub-make saw.
grep -q '^LOOSE_ENV=afterthegap$' obj/sub/build/built.txt

cd $tempdir

##############################################################################
# A --merge-config names a file inside the project that wrote it             #
##############################################################################
# A fragment is written into the Makefile of the project that asked
# for it, through that project's own prefix variable, which is what
# makes one line name one file whether make runs at the top or inside
# the subproject.  A path that climbs out has nothing for that
# variable to attach to.
#
# Asked of the resolved path -- which is what happened before -- a
# subproject's "../frag.config" comes out as the parent's
# "frag.config", climbs out of nothing, and is accepted: so one line
# configures from the top and aborts from inside the subproject, and
# the reading that accepts it writes a bare "frag.config" into the
# subproject's Makefile fragment with no variable in front of it.
merge_tree()
{
    mkdir -p "$1/scripts/kconfig"

    cat >"$1/Kconfig" <<'EOF'
config BASE
	bool "base"
	default y
EOF

    cat >"$1/Makefile" <<'EOF'
O ?= $(CURDIR)/build

all: $(O)/.config
	@mkdir -p $(O)

defconfig:
	@mkdir -p $(O)
	@touch $(O)/.config
EOF

    cat >"$1/scripts/kconfig/merge_config.sh" <<'EOF'
#!/bin/sh
exit 0
EOF
    chmod +x "$1/scripts/kconfig/merge_config.sh"
}

mkdir -p outside/sub
merge_tree outside/sub/kern
echo "CONFIG_X=y" > outside/frag.config

cat >outside/Configfile <<'EOF'
SUBPROJECTS += sub
EOF

cat >outside/sub/Configfile <<'EOF'
BUILD_SYSTEMS += kconfig

SUBPROJECTS   += kern
CONFIGUREOPTS += --merge-config ../frag.config
EOF

if (cd outside && $PTEST_BINARY $PCONFIGURE_ARGS) > outside.out 2>&1
then
    exit 1
fi
cat outside.out
grep -qF "'--merge-config ../frag.config' reaches outside the project that wrote it" \
    outside.out
grep -q "like '--merge-config configs/extra.config'" outside.out
test ! -e outside/Makefile
test ! -e outside/sub/obj/Makefile.sub

# And the same reading from inside the subproject, which is the half
# that was already refused.  One line, one answer, from either
# direction.
if (cd outside/sub && $PTEST_BINARY $PCONFIGURE_ARGS) \
    > outside-inside.out 2>&1
then
    exit 1
fi
cat outside-inside.out
grep -qF "'--merge-config ../frag.config' reaches outside the project that wrote it" \
    outside-inside.out
test ! -e outside/sub/Makefile

# An absolute one is the other way of naming a file no Makefile here
# owns, and it used to be accepted outright.
mkdir -p absolute
merge_tree absolute/kern

cat >absolute/Configfile <<'EOF'
BUILD_SYSTEMS += kconfig

SUBPROJECTS   += kern
CONFIGUREOPTS += --merge-config /etc/hosts
EOF

if (cd absolute && $PTEST_BINARY $PCONFIGURE_ARGS) > absolute.out 2>&1
then
    exit 1
fi
cat absolute.out
grep -q "'--merge-config /etc/hosts' is an absolute path" absolute.out
test ! -e absolute/Makefile

##############################################################################
# An --env is a shell assignment or it is nothing                            #
##############################################################################
# The name in front of the '=' is the one piece of a CONFIGUREOPTS
# that reaches a recipe unquoted, and it has to be: quoted, it stops
# being a shell assignment and becomes the name of a program nobody
# has.  This build system asked only whether there was an '=' in the
# line at all, so the same line another build system refused was taken
# here and turned into an Error 127 in the middle of a build.
mkdir -p bad-env
merge_tree bad-env/kern

cat >bad-env/Configfile <<'EOF'
BUILD_SYSTEMS += kconfig

SUBPROJECTS   += kern
CONFIGUREOPTS += --env 2FOO=bar
EOF

if (cd bad-env && $PTEST_BINARY $PCONFIGURE_ARGS) > bad-env.out 2>&1
then
    exit 1
fi
cat bad-env.out
grep -q "'--env 2FOO=bar' doesn't start with a variable name" bad-env.out
grep -q "the one part of this that can't be quoted" bad-env.out
test ! -e bad-env/Makefile

##############################################################################
# A tree that takes any goal at all, so a recipe that ran two commands       #
# where it should have run one leaves something behind to find              #
##############################################################################
# ".DEFAULT" is make's own answer to a goal it has no rule for, which
# is what every tree below is asked for: the goals here have a ';' in
# them on purpose, so none of them is a rule anybody could write.  It
# means the sub-make succeeds whether or not the quoting works, and
# what tells the two apart is the file the smuggled command would have
# written -- rather than an exit status, which would also be produced
# by a tree that failed for some reason nothing here is about.
inject_tree()
{
    mkdir -p "$1/scripts"

    cat >"$1/Kconfig" <<'EOF'
config BASE
	bool "base"
	default y
EOF

    cat >"$1/Makefile" <<'EOF'
O ?= $(CURDIR)/build

all: $(O)/.config
	@mkdir -p $(O)

defconfig:
	@mkdir -p $(O)
	@touch $(O)/.config

olddefconfig:
	@mkdir -p $(O)

.DEFAULT:
	@mkdir -p $(O)
	@touch $(O)/.config
EOF

    cat >"$1/scripts/config" <<'EOF'
#!/bin/sh
exit 0
EOF
    chmod +x "$1/scripts/config"
}

##############################################################################
# One option is one target                                                   #
##############################################################################
# A --target is quoted on its way into the recipe, which is the
# decision autotools and cmake already made about theirs: one option
# says one target, a tree that wants two of them writes --target
# twice, and so the characters in one of them are characters of a name
# rather than shell syntax.
#
# Left raw -- which is how this was written -- a ';' in a target ends
# the recipe's command and hands the shell whatever came after it to
# run as a program of its own.  That is a Configfile accepted without
# a murmur at configure time, an arbitrary command run by a plain
# "make", and a make that then reports the build succeeded.
mkdir -p inject-target
inject_tree inject-target/kern

cat >inject-target/Configfile <<EOF
BUILD_SYSTEMS += kconfig

SUBPROJECTS   += kern
CONFIGUREOPTS += --target all; touch $tempdir/PWNED-TARGET
EOF

(cd inject-target && $PTEST_BINARY $PCONFIGURE_ARGS)
cat inject-target/Makefile
grep -qF "'all; touch $tempdir/PWNED-TARGET'" inject-target/Makefile

rm -f $tempdir/PWNED-TARGET
(cd inject-target && make $MAKE_ARGS)
test ! -e $tempdir/PWNED-TARGET

##############################################################################
# And so is one defconfig, and one option name, and one option value         #
##############################################################################
# Every one of these lands on a command line the same way a --target
# does: the defconfig is the goal of the sub-make that writes the
# first .config, and the name and the value of a --configure are
# arguments to the tree's own .config editor.  Three more places one
# Configfile line could run a command of its own, and one answer for
# all of them.
mkdir -p inject-config
inject_tree inject-config/kern

cat >inject-config/Configfile <<EOF
BUILD_SYSTEMS += kconfig

SUBPROJECTS   += kern
CONFIGUREOPTS += --defconfig defconfig; touch $tempdir/PWNED-DEFCONFIG
CONFIGUREOPTS += --configure CONFIG_NAME; touch $tempdir/PWNED-NAME =y
CONFIGUREOPTS += --configure CONFIG_VAL=v; touch $tempdir/PWNED-VAL
CONFIGUREOPTS += --configure CONFIG_STR="s"; touch $tempdir/PWNED-STR; "
EOF

(cd inject-config && $PTEST_BINARY $PCONFIGURE_ARGS)
cat inject-config/Makefile
grep -qF "'defconfig; touch $tempdir/PWNED-DEFCONFIG'" inject-config/Makefile
grep -qF -- "--enable 'CONFIG_NAME; touch $tempdir/PWNED-NAME '" \
    inject-config/Makefile
grep -qF -- "--set-val 'CONFIG_VAL' 'v; touch $tempdir/PWNED-VAL'" \
    inject-config/Makefile

# A value written with quotes round it is a string symbol, which is
# the one kind whose value goes into a .config with quotes back on --
# so the quotes the Configfile wrote are what says which kind this is
# and they come off here.  What the tree's own program is handed is
# the string itself, in one argument, with no shell syntax left in it.
grep -qF -- "--set-str 'CONFIG_STR' 's\"; touch $tempdir/PWNED-STR; '" \
    inject-config/Makefile

rm -f $tempdir/PWNED-DEFCONFIG $tempdir/PWNED-NAME
rm -f $tempdir/PWNED-VAL $tempdir/PWNED-STR
(cd inject-config && make $MAKE_ARGS)
test ! -e $tempdir/PWNED-DEFCONFIG
test ! -e $tempdir/PWNED-NAME
test ! -e $tempdir/PWNED-VAL
test ! -e $tempdir/PWNED-STR

##############################################################################
# A second answer to where the tree builds, or to where it installs          #
##############################################################################
# Every one of these is a word that would land on the command line of
# the sub-make that builds the tree, saying something this build
# system has already said there.  Before this, kconfig overrode
# neither take_makeopt() nor already_answered(): the same "DESTDIR="
# that autotools, cmake and cargo each refused was taken here without
# a word, and a plain "make" then installed where the line said.
#
# What makes that worse rather than merely inconsistent is the spelling
# with no install in it at all: "--make-var O=" moves the whole build
# out of the object directory, so every path pconfigure wrote down
# about the tree names a directory the tree never used -- and "make
# distclean" then cleans the empty one.
second_answer()
{
    dir="$1"

    mkdir -p "$dir"
    inject_tree "$dir/kern"

    {
        echo "BUILD_SYSTEMS += kconfig"
        echo ""
        echo "SUBPROJECTS   += kern"
        shift
        for line in "$@"
        do
            echo "$line"
        done
    } > "$dir/Configfile"
    cat "$dir/Configfile"

    if (cd "$dir" && $PTEST_BINARY $PCONFIGURE_ARGS) > "$dir.out" 2>&1
    then
        exit 1
    fi
    cat "$dir.out"
    test ! -e "$dir/Makefile"
}

# The MAKEOPS spelling, which is the one every other build system
# already refused.
second_answer sa-makeops-destdir "MAKEOPS += DESTDIR=$tempdir/elsewhere"
grep -q "'MAKEOPS DESTDIR=$tempdir/elsewhere' sets 'DESTDIR'" \
    sa-makeops-destdir.out
grep -q "says where an install target of this tree writes" \
    sa-makeops-destdir.out
grep -q "the install here runs during 'make' rather than during 'make install'" \
    sa-makeops-destdir.out
grep -q "a directory inside this project's object directory" \
    sa-makeops-destdir.out

# A kbuild tree has no option that says where it installs, because it
# installs nowhere unless a --target asks it to -- so the advice says
# that rather than naming an option nobody could write.
grep -q "there is no option here that says it" sa-makeops-destdir.out
if grep -q -- "--prefix" sa-makeops-destdir.out
then
    exit 1
fi

# The same statement spelled as an option of this build system's own,
# which reaches the same list through add_makeopt() -- and names the
# option the Configfile actually wrote rather than the MAKEOPS it
# shares a list with.
second_answer sa-make-var-destdir \
    "CONFIGUREOPTS += --make-var DESTDIR=$tempdir/elsewhere"
grep -q "'--make-var DESTDIR=$tempdir/elsewhere' sets 'DESTDIR'" \
    sa-make-var-destdir.out

# And spelled for the environment, which kbuild reads just as readily.
second_answer sa-env-destdir \
    "CONFIGUREOPTS += --env DESTDIR=$tempdir/elsewhere"
grep -q "'--env DESTDIR=$tempdir/elsewhere' sets 'DESTDIR'" sa-env-destdir.out

# One per install target a kbuild tree has, which is the whole reason
# this is a list rather than one name: a build system that refused
# DESTDIR and took INSTALL_MOD_PATH would be a closed door with a
# window beside it.
second_answer sa-mod-path \
    "CONFIGUREOPTS += --make-var INSTALL_MOD_PATH=$tempdir/elsewhere"
grep -q "sets 'INSTALL_MOD_PATH'" sa-mod-path.out

second_answer sa-modlib "CONFIGUREOPTS += --make-var MODLIB=$tempdir/elsewhere"
grep -q "sets 'MODLIB'" sa-modlib.out

second_answer sa-install-path \
    "CONFIGUREOPTS += --make-var INSTALL_PATH=$tempdir/elsewhere"
grep -q "sets 'INSTALL_PATH'" sa-install-path.out

second_answer sa-hdr-path \
    "CONFIGUREOPTS += --env INSTALL_HDR_PATH=$tempdir/elsewhere"
grep -q "sets 'INSTALL_HDR_PATH'" sa-hdr-path.out

second_answer sa-dtbs-path \
    "MAKEOPS += INSTALL_DTBS_PATH=$tempdir/elsewhere"
grep -q "sets 'INSTALL_DTBS_PATH'" sa-dtbs-path.out

# And where the tree builds, which this build system writes onto the
# same command line as an "O=$(abspath ...)" and which a second one
# quietly wins: makeopt_flags() comes after it.
second_answer sa-output "CONFIGUREOPTS += --make-var O=$tempdir/elsewhere"
grep -q "'--make-var O=$tempdir/elsewhere' sets 'O'" sa-output.out
grep -q "says where the tree builds" sa-output.out
grep -q "a build directory nothing in this project ever removes" sa-output.out

second_answer sa-kbuild-output \
    "CONFIGUREOPTS += --env KBUILD_OUTPUT=$tempdir/elsewhere"
grep -q "sets 'KBUILD_OUTPUT'" sa-kbuild-output.out

# "M" is the same statement one level down: kbuild.rst documents
# "make -C /path/to/kernel M=$PWD" as how an external module gets
# built against a kernel tree that isn't its own, and it reaches the
# sub-make through the same five channels "O" does.  All five are
# tried here, where "O" above was tried through only two, because
# these were the ones a real Configfile went unrefused on before this
# was fixed.
second_answer sa-m-makeops "MAKEOPS += M=$tempdir/elsewhere"
grep -q "sets 'M'" sa-m-makeops.out
grep -q "says where the tree builds an external module" sa-m-makeops.out

second_answer sa-m-make-var "CONFIGUREOPTS += --make-var M=$tempdir/elsewhere"
grep -q "sets 'M'" sa-m-make-var.out

second_answer sa-m-env "CONFIGUREOPTS += --env M=$tempdir/elsewhere"
grep -q "sets 'M'" sa-m-env.out

second_answer sa-m-target "CONFIGUREOPTS += --target M=$tempdir/elsewhere"
grep -q "'--target M=$tempdir/elsewhere' sets 'M'" sa-m-target.out

second_answer sa-m-defconfig \
    "CONFIGUREOPTS += --defconfig M=$tempdir/elsewhere"
grep -q "'--defconfig M=$tempdir/elsewhere' sets 'M'" sa-m-defconfig.out

# And KBUILD_EXTMOD, which is "M" spelled for the environment the way
# KBUILD_OUTPUT is to "O" -- the same five channels again.
second_answer sa-extmod-makeops "MAKEOPS += KBUILD_EXTMOD=$tempdir/elsewhere"
grep -q "sets 'KBUILD_EXTMOD'" sa-extmod-makeops.out
grep -q "environment spelling of 'M'" sa-extmod-makeops.out

second_answer sa-extmod-make-var \
    "CONFIGUREOPTS += --make-var KBUILD_EXTMOD=$tempdir/elsewhere"
grep -q "sets 'KBUILD_EXTMOD'" sa-extmod-make-var.out

second_answer sa-extmod-env \
    "CONFIGUREOPTS += --env KBUILD_EXTMOD=$tempdir/elsewhere"
grep -q "sets 'KBUILD_EXTMOD'" sa-extmod-env.out

second_answer sa-extmod-target \
    "CONFIGUREOPTS += --target KBUILD_EXTMOD=$tempdir/elsewhere"
grep -q "'--target KBUILD_EXTMOD=$tempdir/elsewhere' sets 'KBUILD_EXTMOD'" \
    sa-extmod-target.out

second_answer sa-extmod-defconfig \
    "CONFIGUREOPTS += --defconfig KBUILD_EXTMOD=$tempdir/elsewhere"
grep -q \
    "'--defconfig KBUILD_EXTMOD=$tempdir/elsewhere' sets 'KBUILD_EXTMOD'" \
    sa-extmod-defconfig.out

# And KCONFIG_CONFIG, which this build system already sets itself
# whenever a --merge-config is in play (see vendored_targets()) -- so
# it already knows the name, and a Configfile that also set it would
# move the .config this reads back after configuring and writes into
# the fragment kbuild_output() and config_file() both point at.
second_answer sa-kconfig-config \
    "CONFIGUREOPTS += --make-var KCONFIG_CONFIG=$tempdir/elsewhere"
grep -q "sets 'KCONFIG_CONFIG'" sa-kconfig-config.out
grep -q "says where the tree's .config lives" sa-kconfig-config.out

second_answer sa-kconfig-config-env \
    "CONFIGUREOPTS += --env KCONFIG_CONFIG=$tempdir/elsewhere"
grep -q "sets 'KCONFIG_CONFIG'" sa-kconfig-config-env.out

# A goal and a variable arrive on the same command line and make tells
# them apart by the '=' -- so a --target that is a variable is a
# variable, and the tree's default goal gets built with it set.  This
# is the way round the check that only read --make-var and MAKEOPS.
second_answer sa-target-var \
    "CONFIGUREOPTS += --target INSTALL_MOD_PATH=$tempdir/elsewhere"
grep -q "'--target INSTALL_MOD_PATH=$tempdir/elsewhere' sets" sa-target-var.out

second_answer sa-defconfig-var \
    "CONFIGUREOPTS += --defconfig O=$tempdir/elsewhere"
grep -q "'--defconfig O=$tempdir/elsewhere' sets 'O'" sa-defconfig-var.out

##############################################################################
# And the option that is about the destination rather than a name            #
##############################################################################
# The refusals above are about a line that says where an install goes,
# not about asking for an install at all: a "--target modules_install"
# is a goal like any other and the tree installs where its own
# variables already point, which is inside the output directory this
# build system handed it.  Without this, every one of them would be
# satisfied by a build system that refused the option outright.
mkdir -p allowed
inject_tree allowed/kern

# A stand-in for a kbuild tree's install target that RECORDS where it
# was told to write rather than writing anything there.  Nothing in
# this test is ever allowed to run a real install.
cat >>allowed/kern/Makefile <<'EOF'

modules_install:
	@mkdir -p $(O)
	@echo "DESTDIR=[$(DESTDIR)]" > $(O)/where.txt
	@echo "INSTALL_MOD_PATH=[$(INSTALL_MOD_PATH)]" >> $(O)/where.txt
	@echo "O=[$(O)]" >> $(O)/where.txt
EOF

cat >allowed/Configfile <<'EOF'
BUILD_SYSTEMS += kconfig

SUBPROJECTS   += kern
CONFIGUREOPTS += --target modules_install
EOF

(cd allowed && $PTEST_BINARY $PCONFIGURE_ARGS)
(cd allowed && make $MAKE_ARGS)
cat allowed/obj/kern/build/where.txt

# Neither destination was said by anybody, so the tree's own defaults
# stand -- and the one directory that was said is the one this build
# system decided.
grep -q '^DESTDIR=\[\]$' allowed/obj/kern/build/where.txt
grep -q '^INSTALL_MOD_PATH=\[\]$' allowed/obj/kern/build/where.txt
# Matched without the directory in front of it, because "$(abspath)"
# is make's and make hands back the path with every symbolic link
# taken out -- which on this machine turns the "/var" a mktemp -d
# names into the "/private/var" it is.  What is being asserted is the
# tail: the tree built into the object directory of the project that
# vendored it, which is the thing an "O=" of somebody else's would
# have moved.
grep -q "^O=\[/.*/allowed/obj/kern/build\]\$" \
    allowed/obj/kern/build/where.txt

exit 0
