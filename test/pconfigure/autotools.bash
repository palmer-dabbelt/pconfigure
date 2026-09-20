#include "harness_start.bash"

top="$tempdir"

##############################################################################
# The programs an autotools tree is built with                               #
##############################################################################
# Running a vendored autotools tree means running autoconf and then
# running the configure it wrote, and neither of those is a thing this
# machine can be relied on to have -- a build box with no autoconf on
# it is exactly the box somebody vendors a tarball for.  These stand
# in for them: programs named the way autotools names its programs,
# which write down how they were called and then do the smallest
# thing that keeps the build moving.
#
# What's under test here is the command line pconfigure writes and the
# directory it writes it in, not what autoconf does once it's been
# run -- so a fake that copies a canned configure into place is as
# good as the real thing would be, and it has the considerable
# advantage of behaving the same way on every machine.  A real
# autoconf changes what it emits between releases, and every one of
# those changes is a way for this test to start failing for a reason
# that has nothing to do with pconfigure.
#
# Both of them refuse to run when they haven't been given what they
# have to be given, and each of those three refusals is the net under
# an assertion further down: "the one file written inside the tree was
# written by the tree's own bootstrap" rests on autoconf refusing to
# run anywhere but in the tree, "the tree came back exactly as it was
# found" rests on configure refusing to run in the tree it is
# configuring, and everything said here about where a tree installs
# rests on configure refusing to run without a --prefix at all.  A
# fake that tolerated any of those would prove nothing about what it
# was handed.
#
# Nothing pconfigure writes today is wrong in any of those ways, which
# is exactly the problem: a net with a typo in it catches nothing
# while looking precisely like one that works.  So the three arms are
# taken deliberately, once, by the block below headed "The fakes'
# refusals" -- and by nothing else in this file, which is what that
# block is for.
#
# It lives beside the fixture rather than inside it: anything under
# "sub" is something pconfigure may chase as a dependency and
# something the "nothing was written in the tree" assertions have to
# reason about.
fakedir="$top/fake"
mkdir -p $fakedir

# Where the fake autoconf writes down that it ran, named through a
# variable rather than baked in so that the refusals below can be
# taken without leaving a line in it: that log is a record of what the
# Makefile did, and a probe of the fake is not something the Makefile
# did.
export AUTOCONF_FAKE_LOG="$fakedir/ran.log"

cat >$fakedir/autoconf <<EOF
#!/bin/sh
echo "autoconf \$@ in \$(pwd)" >> "\$AUTOCONF_FAKE_LOG"

if [ ! -f configure.ac ]
then
    echo "autoconf: there is no configure.ac in \$(pwd)" 1>&2
    exit 1
fi

cp $fakedir/configure.template ./configure
chmod +x ./configure
EOF
chmod +x $fakedir/autoconf

# The quoted heredoc is what keeps the shell writing this file from
# reading the "$@" and the "$srcdir" that the shell running it is
# supposed to read.
cat >$fakedir/configure.template <<'EOF'
#!/bin/sh
set -e

# Which is how a real configure works out where its sources are, and
# the reason pconfigure has to name it absolutely.
srcdir=$(cd "$(dirname "$0")" && pwd)

if [ "$srcdir" = "$(pwd)" ]
then
    echo "configure: run inside the source tree" 1>&2
    exit 1
fi

prefix=
for arg in "$@"
do
    case "$arg" in
    --prefix=*) prefix="${arg#--prefix=}" ;;
    esac
done

if [ -z "$prefix" ]
then
    echo "configure: run without a --prefix" 1>&2
    exit 1
fi

# One line per argument, so that an argument with a space in it can be
# told from two arguments.
printf '%s\n' "$@" > configure.args
echo "argv0=$0" > configure.env
echo "MY_ENV=$MY_ENV" >> configure.env

# An environment variable whose value has a space in it, which is the
# one that tells a quoted assignment from an unquoted one: unquoted,
# the shell reads the second word as a command to run rather than as
# the rest of the value, and the recipe dies before configure is ever
# reached.
echo "MY_FLAGS=$MY_FLAGS" >> configure.env

sed -e "s|@srcdir@|$srcdir|g" -e "s|@prefix@|$prefix|g" \
    "$srcdir/Makefile.in" > Makefile

echo "configured" > config.status
EOF

export PATH="$fakedir:$PATH"

##############################################################################
# The fakes' refusals                                                        #
##############################################################################
# Taken here on purpose, because nothing else in this file reaches
# them: pconfigure has never bootstrapped a tree from outside it,
# never run a configure inside the tree it is configuring, and never
# left the prefix off.  Which is what the arms are there to catch, and
# also the reason they have to be run deliberately -- an arm no
# scenario ever takes is an arm whose typo nobody ever finds, and the
# net that catches nothing looks exactly like the one that works.
#
# In a directory of their own beside the fixture, so that what these
# runs leave behind is not something a "nothing was written in the
# tree" assertion further down has to reason about.
probe="$fakedir/probe"
mkdir -p $probe/build

# autoconf, run where there is no configure.ac.  A tree is
# bootstrapped from inside itself because that is where autoconf's
# input is and the only place it writes its output -- so this refusal
# is what stands behind the claim that the configure in the tree was
# put there by a bootstrap run in the tree.
#
# Through a log of its own, since this run is not one the Makefile
# made.
if (cd $probe && AUTOCONF_FAKE_LOG=$probe/ran.log autoconf) \
    > $probe/no-configure-ac.out 2>&1
then
    exit 1
fi
grep -q "autoconf: there is no configure.ac in" $probe/no-configure-ac.out

# And it wrote no configure, which is the half of that refusal that
# matters: the generated configure is the one file this build system
# ever puts inside somebody else's checkout.
test ! -e $probe/configure

# configure, run from the directory it is standing in.  Out of tree is
# the only way anything here gets built, and that is a decision rather
# than an omission, so this refusal is what stands behind every "the
# vendored tree came back as it was found" below.  It is handed a
# --prefix so that this run is wrong in exactly one way.
cp $fakedir/configure.template $probe/configure
chmod +x $probe/configure
if (cd $probe && ./configure --prefix=$probe/prefix) \
    > $probe/in-tree.out 2>&1
then
    exit 1
fi
grep -q "configure: run inside the source tree" $probe/in-tree.out

# And configure run out of tree with no prefix at all, which is what
# stands behind everything this file says about where a tree installs:
# a configure that took silence for an answer would install into
# /usr/local and say nothing about it.
if (cd $probe/build && $probe/configure) > $probe/no-prefix.out 2>&1
then
    exit 1
fi
grep -q "configure: run without a --prefix" $probe/no-prefix.out

# And both of those refused before writing anything, which is what
# makes the assertions below claims about how far pconfigure got
# rather than about how far the fake got.
test ! -e $probe/configure.args
test ! -e $probe/build/configure.args
test ! -e $probe/build/Makefile

##############################################################################
# A tree that ships no configure, the way a checkout of one looks        #
##############################################################################
mkdir -p sub/src sub2/src sub3/src

# No "configure" here: it is the generated file, and a project that
# keeps one in version control is a project with a merge conflict
# waiting for it.  Making one is part of what this build system does.
cat >sub/configure.ac <<'EOF'
AC_INIT([sub], [1.0])
AC_CONFIG_FILES([Makefile])
AC_OUTPUT
EOF

# "all" is first on purpose, since a sub-make handed no target at all
# runs whichever target the tree's Makefile happens to mention first.
# It is also deliberately not the target this tree gets asked for:
# with "all" and "hello" doing different things, a --target that was
# quietly dropped shows up as the wrong file being written rather than
# as nothing at all.
#
# Everything the tree was told gets written back out where the test
# can read it.  A variable make was handed on its command line and a
# variable that was never set look identical from out here unless the
# tree says which one it saw, and the same goes for the srcdir it was
# configured with.
cat >sub/Makefile.in <<'EOF'
srcdir = @srcdir@
prefix = @prefix@

all:
	@echo "the default target ran" > default.txt

hello:
	@echo "built" > built.txt
	@echo "MY_VAR=$(MY_VAR)" >> built.txt
	@cp $(srcdir)/src/hello.c hello.c

install: hello
	@mkdir -p $(prefix)/bin
	@cp built.txt $(prefix)/bin/hello
	@echo "MY_VAR=$(MY_VAR)" > $(prefix)/bin/installed.txt

.PHONY: all hello install
EOF

cat >sub/src/hello.c <<'EOF'
int hello(void) { return 1; }
EOF

##############################################################################
# And one that does, the way a release tarball looks                         #
##############################################################################
# Same build system, other state of the world: everything autoconf
# would have written is already here, so nothing should try to write
# it again.  This one also stands in for the tree that is built and
# not installed, which is what a project that only wants to name a
# file out of the build directory asks for.
cp $fakedir/configure.template sub2/configure
chmod +x sub2/configure

cat >sub2/Makefile.in <<'EOF'
srcdir = @srcdir@
prefix = @prefix@

all:
	@echo "built" > built.txt
	@cp $(srcdir)/src/world.c world.c

install: all
	@mkdir -p $(prefix)/bin
	@cp built.txt $(prefix)/bin/world

.PHONY: all install
EOF

cat >sub2/src/world.c <<'EOF'
int world(void) { return 2; }
EOF

##############################################################################
# And one that installs into the object directory                            #
##############################################################################
# Somewhere in the object directory that is not this tree's own
# output directory, which is the shape a --prefix exists to write:
# several trees landing in one place.  It is also the shape that
# needs the cleaning code's help, because "make cache-clean" reclaims
# the object directory by reading the Makefile back and deleting
# everything under it that no rule builds -- and an installed tree is
# exactly that: the Makefile names a build stamp and whatever a
# SUBPROJECT_TARGETS mentioned, and nothing else.  A tree's own output
# directory is spared for its own reasons; a prefix beside it is
# spared because project::cache_clean_target() is told where it is.
#
# Three files, and no SUBPROJECT_TARGETS naming any of them.  That is
# what tells "the prefix survived" from "the one path the Makefile
# happens to name survived".
cp $fakedir/configure.template sub3/configure
chmod +x sub3/configure

cat >sub3/Makefile.in <<'EOF'
srcdir = @srcdir@
prefix = @prefix@

all:
	@echo "built" > built.txt

install: all
	@mkdir -p $(prefix)/bin $(prefix)/lib $(prefix)/include
	@cp built.txt $(prefix)/bin/tool
	@echo "installed" > $(prefix)/lib/libtool.a
	@echo "installed" > $(prefix)/include/tool.h

.PHONY: all install
EOF

##############################################################################
# The project that vendors them                                              #
##############################################################################
# Nothing inside either tree says a word about pconfigure: BUILD_SYSTEMS
# says autotools is available, and which subproject gets built that way
# is worked out from what's in the directory.
#
# "obj/stage" is a prefix of the project's own rather than the one
# this defaults to, because a shared install directory is the usual
# reason to want the option at all: a vendored toolchain is found by
# looking one "bin" up, and several trees have to agree on which one.
# It is inside the object directory because that is what an install
# prefix is -- see build_system::install_dir() -- and the refusals at
# the bottom of this file are what says so.
cat >Configfile <<'EOF'
BUILD_SYSTEMS += autotools

SUBPROJECTS   += sub
CONFIGUREOPTS += --prefix obj/stage
CONFIGUREOPTS += --configure-flag --enable-extra
CONFIGUREOPTS += --configure-var YACC=fakebison
CONFIGUREOPTS += --configure-var CXXFLAGS=-g -O2
CONFIGUREOPTS += --env MY_ENV=one
CONFIGUREOPTS += --env MY_FLAGS=-O2 -g
CONFIGUREOPTS += --make-var MY_VAR=first
CONFIGUREOPTS += --target hello
SUBPROJECT_TARGETS += bin/hello

SUBPROJECTS   += sub2
CONFIGUREOPTS += --no-install
SUBPROJECT_TARGETS += built.txt

SUBPROJECTS   += sub3
CONFIGUREOPTS += --prefix obj/shared
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

##############################################################################
# What configure time wrote, and what it did not                             #
##############################################################################
# Nothing at all was written inside either vendored tree.  The
# generated configure is the one file this build system ever puts in
# there, and it is a make-time thing: at configure time the tree is
# still exactly as it was found.
test ! -e sub/configure
test ! -e sub/Makefile
test ! -e sub/config.status
test ! -e sub/obj
test ! -e sub2/Makefile
test ! -e sub2/config.status

# The one thing configure time does write on this side of the fence is
# the list of options the tree is about to be configured with, which
# has to exist before make runs because make is what compares it
# against the last one.  The build directory itself is still make's to
# create, and so is the prefix.
test -f obj/sub/configure-opts
test -f obj/sub2/configure-opts
test ! -e obj/sub/build
test ! -e obj/sub/build-stamp
test ! -e obj/stage

# One raw CONFIGUREOPTS line per line, in the order they were written,
# plus the one thing in the recipe that nobody wrote as an option:
# which program makes the tree's configure is worked out by looking at
# the tree, so a tree that grows a Makefile.am gets bootstrapped by a
# different command than the last Makefile said -- and a recipe
# changing is not a reason for make to run a rule.
cat obj/sub/configure-opts
cat >expected-opts <<'EOF'
--prefix obj/stage
--configure-flag --enable-extra
--configure-var YACC=fakebison
--configure-var CXXFLAGS=-g -O2
--env MY_ENV=one
--env MY_FLAGS=-O2 -g
--make-var MY_VAR=first
--target hello
bootstrap autoconf
EOF
diff expected-opts obj/sub/configure-opts

# The tree that ships its own configure has nothing to bootstrap, so
# it has nothing to say about it either.  A line no recipe reads would
# reconfigure a tree over a change that can't reach it.
cat obj/sub2/configure-opts
cat >expected-opts2 <<'EOF'
--no-install
EOF
diff expected-opts2 obj/sub2/configure-opts

##############################################################################
# The rules                                                                  #
##############################################################################
# They live in the Makefile of whoever pulled the trees in, since
# there's nowhere else for them to go.
grep -q "^sub/configure:" Makefile
grep -q "^obj/sub/build/config.status:" Makefile
grep -q "^obj/sub/build-stamp:" Makefile
grep -q "^all: obj/sub/build-stamp$" Makefile

# The tree that ships a configure gets no rule to make one.  Its
# positive twin is right above: the pattern spells something that does
# turn up in this Makefile, for the tree that needs it.
if grep -q "^sub2/configure:" Makefile
then
    exit 1
fi
grep -q "^obj/sub2/build/config.status:" Makefile

# Out of tree, and named absolutely.  configure works out where its
# sources are from the path it was run as, so a relative one would
# make the tree's own srcdir relative too -- and then every generated
# Makefile in every subdirectory of the build would be pointing at a
# different number of "..".
grep -q "cd obj/sub/build && MY_ENV='one' MY_FLAGS='-O2 -g' \$(abspath sub)/configure" Makefile
grep -q -- "'--prefix=\$(abspath obj/stage)'" Makefile

# An --env is an assignment with a quoted value on it, which is the
# only shape that works: the name has to stay outside the quotes or
# the shell reads the whole "NAME=VALUE" as the name of a program to
# run, and the value has to be inside them or a space in it ends the
# assignment and starts a command.  "CFLAGS=-O2 -g" is a thing people
# write and mean, and unquoted it gets as far as "-g: command not
# found" at build time having been accepted without a murmur here.
grep -q -- "MY_ENV='one' MY_FLAGS='-O2 -g' " Makefile
if grep -q -- "MY_ENV='one' MY_FLAGS=-O2" Makefile
then
    exit 1
fi
if grep -q -- "'MY_ENV=one'" Makefile
then
    exit 1
fi

# One configure argument is one shell word, however many spaces are in
# it: "CXXFLAGS=-g -O2" is a thing people write and mean, and what the
# shell does with it unquoted is hand configure a CXXFLAGS worth "-g"
# and then an "-O2" that configure reads as a flag of its own.
grep -q -- "'--enable-extra'" Makefile
grep -q -- "'YACC=fakebison'" Makefile
grep -q -- "'CXXFLAGS=-g -O2'" Makefile

# make is run in the build directory and never in the tree, which is
# the whole of what an out-of-tree build is.  The positive twin is on
# the line below, so that the absence above is an absence of something
# this Makefile knows how to spell.
if grep -q -- "-C sub " Makefile
then
    exit 1
fi
grep -q -- "-C obj/sub/build" Makefile

# What a SUBPROJECT_TARGETS names is relative to wherever the tree last
# wrote something, which is the prefix for a tree that installs and the
# build directory for one that doesn't.  A build directory is objects
# and libtool wrappers whose layout is nobody's business but the
# tree's; the installed layout is the one thing an autotools tree
# really does promise.
grep -q "^obj/stage/bin/hello: obj/sub/build-stamp$" Makefile
grep -q "^all: obj/stage/bin/hello$" Makefile
grep -q "^obj/sub2/build/built.txt: obj/sub2/build-stamp$" Makefile

# And a tree told not to install has no prefix for any rule to empty.
# One line in the whole Makefile mentions the default prefix of the
# tree that doesn't install, and it is the "--prefix=" configure is
# handed, because autotools insists on being told one whether anything
# installs or not.  The two rules that empty a prefix -- the
# reconfigure and the clean -- leave this one alone: the directory is
# one nothing in this configuration ever creates, so a rule that
# reached for it would be a recipe saying this build installs
# somewhere when it doesn't.  Harmless to run, and a lie to read.
#
# Counted rather than grepped for, because it is asserted on the
# Makefile rather than on the filesystem: a directory that was never
# made is one an "rm -fr" removes exactly as successfully as one that
# was, so nothing about running it could say which happened.
grep -c "obj/sub2/prefix" Makefile | tr -d ' ' > sub2-prefix-lines
cat sub2-prefix-lines
test "$(cat sub2-prefix-lines)" = "1"

##############################################################################
# Building                                                                   #
##############################################################################
make $MAKE_ARGS > first.out
cat first.out

# Three phases, and the labels are how they're told apart from out
# here: make recursing into somebody else's tree is invisible
# otherwise.  The tab has to be a real one rather than something a
# grep pattern hopes is there.
tab="$(printf '\t')"
grep -q "AUTORECONF${tab}sub$" first.out
grep -q "AUTOTOOLS${tab}sub$" first.out
grep -q "MAKE${tab}sub$" first.out

# The one file this ever writes inside a vendored tree, written by the
# tree's own bootstrap program from inside the tree -- which the fake
# autoconf refuses to do from anywhere else.
test -f sub/configure
cat $fakedir/ran.log
grep -q "^autoconf .* in .*/sub$" $fakedir/ran.log

# And nothing else got written in there.  The Makefile and the
# config.status are in the build directory, where an out-of-tree build
# puts them.
test ! -e sub/Makefile
test ! -e sub/config.status
test ! -e sub/built.txt
test ! -e sub/hello.c
test -f obj/sub/build/Makefile
test -f obj/sub/build/config.status

# What configure was actually handed, rather than what the Makefile
# says it would be handed.  The prefix is absolute because autotools
# bakes it into what it builds, and configure itself was named
# absolutely because that is where it looks for its sources.
cat obj/sub/build/configure.args
grep -q "^--prefix=/.*/obj/stage$" obj/sub/build/configure.args
grep -q "^--enable-extra$" obj/sub/build/configure.args
grep -q "^YACC=fakebison$" obj/sub/build/configure.args
grep -q "^CXXFLAGS=-g -O2$" obj/sub/build/configure.args

cat obj/sub/build/configure.env
grep -q "^argv0=/" obj/sub/build/configure.env
grep -q "^MY_ENV=one$" obj/sub/build/configure.env

# And what the environment variable with a space in it was actually
# worth by the time configure read it, which is the half of the
# quoting the Makefile can't show: a value that got split would arrive
# here as "-O2" with the rest of it gone.
grep -q "^MY_FLAGS=-O2 -g$" obj/sub/build/configure.env

# The target that was asked for is the one that ran, and the tree's
# own default is the one that didn't.  Asking the tree is the only way
# to tell those apart: a --target that was quietly dropped would still
# have left a build behind.
test -f obj/sub/build/built.txt
test ! -e obj/sub/build/default.txt

# A MAKEOPS reaches the sub-make's command line, and the srcdir the
# tree was configured with reaches its sources.
cat obj/sub/build/built.txt
grep -q "^MY_VAR=first$" obj/sub/build/built.txt
test -f obj/sub/build/hello.c

# The install ran, into the prefix that was asked for -- and it was
# handed the variables too, which is a separate sub-make and so a
# separate thing to get wrong.
test -f obj/stage/bin/hello
cat obj/stage/bin/installed.txt
grep -q "^MY_VAR=first$" obj/stage/bin/installed.txt

# The tree that was told not to install didn't, and built what it
# builds when it's asked for nothing.
test -f obj/sub2/build/built.txt
test -f obj/sub2/build/world.c
test ! -e obj/sub2/prefix

test -f obj/sub/build-stamp
test -f obj/sub2/build-stamp

##############################################################################
# A second make has nothing to do                                            #
##############################################################################
# Which is the whole point of the dependency guess: the build itself
# is the tree's own make, and going back in there to be told there was
# nothing to do costs a walk of the tree every time.
make $MAKE_ARGS > second.out
cat second.out
if grep -q "AUTORECONF" second.out
then
    exit 1
fi
if grep -q "AUTOTOOLS" second.out
then
    exit 1
fi
if grep -q "MAKE" second.out
then
    exit 1
fi

##############################################################################
# And a changed input does exactly as much as it has to                      #
##############################################################################
# The sleep is what keeps each of these from being a statement about
# the filesystem's clock instead: a write inside the same mtime tick
# as the stamp looks identical to no write at all.
#
# A source file is something only the build reads, so only the build
# runs.
sleep 2s
touch sub/src/hello.c
make $MAKE_ARGS > third.out
cat third.out
grep -q "MAKE${tab}sub$" third.out
if grep -q "AUTOTOOLS" third.out
then
    exit 1
fi
if grep -q "AUTORECONF" third.out
then
    exit 1
fi

# A template configure fills in is something configure reads, so
# configure runs -- and the build after it, since the Makefile it
# just rewrote is the one the build uses.  The tree's own generated
# Makefiles have rules for this too, but those only ever fire once
# make is already inside the build directory, and whether make goes in
# there at all is what these rules decide.
sleep 2s
touch sub/Makefile.in
make $MAKE_ARGS > fourth.out
cat fourth.out
grep -q "AUTOTOOLS${tab}sub$" fourth.out
grep -q "MAKE${tab}sub$" fourth.out
if grep -q "AUTORECONF" fourth.out
then
    exit 1
fi

# And the configure.ac goes all the way back to the beginning, which
# is the chain this build system exists to get right: autoconf writes
# a new configure, the new configure is run, and the build follows it.
sleep 2s
touch sub/configure.ac
make $MAKE_ARGS > fifth.out
cat fifth.out
grep -q "AUTORECONF${tab}sub$" fifth.out
grep -q "AUTOTOOLS${tab}sub$" fifth.out
grep -q "MAKE${tab}sub$" fifth.out

##############################################################################
# A changed CONFIGUREOPTS reconfigures                                       #
##############################################################################
# Every prerequisite these rules have is a file that belonged to the
# tree or to the project before pconfigure ran, and a recipe changing
# is not a reason for make to run a rule.  So without the options
# being written into a file of their own, a tree reconfigured with
# different flags would sit there configured the old way underneath a
# Makefile that said otherwise.
sleep 2s
sed 's/--enable-extra/--enable-other/' Configfile > Configfile.new
mv Configfile.new Configfile
cat Configfile
$PTEST_BINARY $PCONFIGURE_ARGS

make $MAKE_ARGS > sixth.out
cat sixth.out
grep -q "AUTOTOOLS${tab}sub$" sixth.out
grep -q "MAKE${tab}sub$" sixth.out

# What the tree ended up with, rather than just the fact that make
# went in there.  Asserting on the arguments configure was handed is
# the only way to tell a reconfigure from a rebuild that reused the
# config.status it found lying around.
cat obj/sub/build/configure.args
grep -q "^--enable-other$" obj/sub/build/configure.args
if grep -q "^--enable-extra$" obj/sub/build/configure.args
then
    exit 1
fi

##############################################################################
# Cleaning                                                                   #
##############################################################################
# A clean takes the stamp and nothing else: what the tree built is the
# tree's, and throwing it away would make "make clean" cost an hour of
# somebody's day rather than a second.  What removing the stamp buys
# is that the next make goes back in and lets the tree decide.
make $MAKE_ARGS clean
test ! -e obj/sub/build-stamp
test -f obj/sub/build/config.status
test -f obj/stage/bin/hello

make $MAKE_ARGS > seventh.out
cat seventh.out
grep -q "MAKE${tab}sub$" seventh.out
if grep -q "AUTOTOOLS" seventh.out
then
    exit 1
fi

# A vendored build lands in this project's object directory, where
# cache-clean would otherwise read the Makefile back, find that it
# says nothing about any of it, and throw away a build that's
# perfectly good.
make $MAKE_ARGS cache-clean
test -f obj/sub/build/config.status
test -f obj/sub/build/built.txt
test -f obj/stage/bin/hello

# And so does what a vendored tree installed.  "obj/shared" is inside
# the object directory and outside that tree's own output directory,
# which is the shape that needs saying: the three files below have no
# rule behind them, so a cache-clean that read the Makefile back and
# believed it would delete every one of them -- and leave the build
# stamp saying the tree is installed, so no later make would put any
# of them back.  The first thing to fail would be a compile against a
# header that was there yesterday.
test -f obj/shared/bin/tool
test -f obj/shared/lib/libtool.a
test -f obj/shared/include/tool.h

make $MAKE_ARGS > eighth.out
cat eighth.out
if grep -q "MAKE" eighth.out
then
    exit 1
fi

##############################################################################
# Distclean                                                                  #
##############################################################################
# Undoing a configure throws away what the vendored build system
# produced, and leaves the vendored tree exactly as it was -- except
# for the generated configure, which stays.  Nothing removes that:
# "make distclean" takes this project's object directory, and that is
# not a licence to reach into somebody else's checkout and delete a
# file out of it.
#
# Read out before it is run, since running it takes the Makefile too.
# An install prefix is a directory inside the object directory, so
# removing the object directory removes it -- and a distclean that
# also wrote the prefix down would be pasting a path somebody typed
# into a Configfile straight into an "rm -rf", which is a thing
# nothing here needs to be right about.  Neither of the two prefixes
# this project installs into is named in the recipe, and both of them
# are gone below.
sed -n '/^distclean:/,/^$/p' Makefile > distclean.rule
cat distclean.rule
grep -q "rm -rf 'obj'$" distclean.rule
if grep -q "rm -rf 'obj/stage'" distclean.rule
then
    exit 1
fi
if grep -q "rm -rf 'obj/shared'" distclean.rule
then
    exit 1
fi

make $MAKE_ARGS distclean
test ! -e obj/sub
test ! -e obj/sub2

# Including what the trees installed, which is the other half of the
# same answer: cache-clean spares an install prefix because it cannot
# tell one from stale, and distclean takes it because it is build
# output and a fresh checkout hasn't got one.
test ! -e obj/stage
test ! -e obj/shared

test -f sub/configure.ac
test -f sub/Makefile.in
test -f sub/src/hello.c
test -f sub/configure
test ! -e sub/Makefile
test ! -e sub/config.status
test ! -e sub/built.txt
test -f sub2/configure
test ! -e sub2/Makefile

##############################################################################
# What an install left behind, when the prefix is this tree's own            #
##############################################################################
# A vendored tree's install has no rules behind it: the recipe that
# configures, builds and installs hangs off one stamp, and the
# programs, libraries and headers that land in the prefix are named by
# nothing.  So the only thing that ever removes a file from in there
# is something that removes the directory, and without one a tree that
# stopped installing a program goes on having installed it -- in the
# directory build_dir() resolves every SUBPROJECT_TARGETS against, the
# directory the rest of the build links against, and the directory
# anything looking one "bin" up finds first.
#
# This is the tree that has no --prefix, which is the half of the
# question that has a clean answer: the default prefix is a directory
# inside this tree's own output directory that nothing else writes to,
# so emptying it costs one reinstall and is nobody else's business.
# The section after this one is the other half.
#
# Which file gets installed comes from a variable, so that the two
# configurations differ in what they install rather than in what they
# build -- a rebuild would hide the whole question.
mkdir -p $top/own-install/sub
cp $fakedir/configure.template $top/own-install/sub/configure
chmod +x $top/own-install/sub/configure

# printf rather than a heredoc, so that the tab a recipe line has to
# start with is a tab rather than whatever a later edit leaves there.
printf 'srcdir = @srcdir@\nprefix = @prefix@\n\nall:\n\t@echo built > built.txt\n\ninstall: all\n\t@mkdir -p $(prefix)/bin\n\t@cp built.txt $(prefix)/bin/$(TOOL)\n\n.PHONY: all install\n' \
    > $top/own-install/sub/Makefile.in

own_install_configfile()
{
    {
        echo "BUILD_SYSTEMS += autotools"
        echo ""
        echo "SUBPROJECTS   += sub"
        echo "CONFIGUREOPTS += --make-var TOOL=$1"
    } > $top/own-install/Configfile
}

own_install_configfile tool-a
(cd $top/own-install && $PTEST_BINARY $PCONFIGURE_ARGS && make $MAKE_ARGS)
test -f $top/own-install/obj/sub/prefix/bin/tool-a

# A reconfigure starts the install over.  The option changed, so the
# tree is configured again and built and installed again -- and what
# the last configuration installed and this one doesn't is a file that
# would otherwise still be sitting there, still satisfying a "test -e",
# with a stamp above it saying the tree is installed and so no later
# make ever putting the question again.
own_install_configfile tool-b
(cd $top/own-install && $PTEST_BINARY $PCONFIGURE_ARGS && make $MAKE_ARGS)
test -f $top/own-install/obj/sub/prefix/bin/tool-b
test ! -e $top/own-install/obj/sub/prefix/bin/tool-a

# And so does a clean, which costs it nothing it wasn't already
# costing: a clean takes the stamp, so the next make re-enters the tree
# and installs again anyway.  The build directory is deliberately still
# there -- that is an hour of somebody's day for a real tree, and a
# clean is not the target that gets to spend it.
(cd $top/own-install && make $MAKE_ARGS clean)
test ! -e $top/own-install/obj/sub/build-stamp
test ! -e $top/own-install/obj/sub/prefix
test -f $top/own-install/obj/sub/build/config.status

(cd $top/own-install && make $MAKE_ARGS)
test -f $top/own-install/obj/sub/prefix/bin/tool-b

##############################################################################
# And a prefix somebody named, which is nobody's to empty                    #
##############################################################################
# The other half, and the reason the half above is written as narrowly
# as it is.  A --prefix is written down because several trees are meant
# to land in one directory, so the files in there belong to whichever
# tree installed them -- and a tree that emptied it on its way past
# would be deleting a peer's install.  Nothing would put that back:
# the peer's stamp still says it has been built, so no later make goes
# near it, and the first thing to fail is a link against a library that
# was there yesterday.
#
# Two trees, one prefix, one file each, and only the first tree's
# options are changed.  That is what makes this an assertion about the
# other tree rather than about this one: tree "a" is reconfigured and
# reinstalls its own file whatever happens, while tree "b" installs
# nothing at all during the second make.
mkdir -p $top/shared-install/a $top/shared-install/b
cp $fakedir/configure.template $top/shared-install/a/configure
cp $fakedir/configure.template $top/shared-install/b/configure
chmod +x $top/shared-install/a/configure $top/shared-install/b/configure

printf 'srcdir = @srcdir@\nprefix = @prefix@\n\nall:\n\t@echo built > built.txt\n\ninstall: all\n\t@mkdir -p $(prefix)/bin\n\t@cp built.txt $(prefix)/bin/tool-a\n\n.PHONY: all install\n' \
    > $top/shared-install/a/Makefile.in
printf 'srcdir = @srcdir@\nprefix = @prefix@\n\nall:\n\t@echo built > built.txt\n\ninstall: all\n\t@mkdir -p $(prefix)/bin\n\t@cp built.txt $(prefix)/bin/tool-b\n\n.PHONY: all install\n' \
    > $top/shared-install/b/Makefile.in

shared_install_configfile()
{
    {
        echo "BUILD_SYSTEMS += autotools"
        echo ""
        echo "SUBPROJECTS   += a"
        echo "CONFIGUREOPTS += --prefix obj/shared"
        echo "CONFIGUREOPTS += --configure-flag $1"
        echo ""
        echo "SUBPROJECTS   += b"
        echo "CONFIGUREOPTS += --prefix obj/shared"
    } > $top/shared-install/Configfile
}

shared_install_configfile --enable-one
(cd $top/shared-install && $PTEST_BINARY $PCONFIGURE_ARGS && make $MAKE_ARGS)
test -f $top/shared-install/obj/shared/bin/tool-a
test -f $top/shared-install/obj/shared/bin/tool-b

shared_install_configfile --enable-two
(cd $top/shared-install && $PTEST_BINARY $PCONFIGURE_ARGS && make $MAKE_ARGS)
grep -q "^--enable-two$" $top/shared-install/obj/a/build/configure.args
test -f $top/shared-install/obj/shared/bin/tool-a
test -f $top/shared-install/obj/shared/bin/tool-b

# And a clean leaves it alone for the same reason, which is the one
# place the two halves of this really do behave differently: a clean
# that emptied a shared prefix would take both trees' installs, and put
# back only the ones the next make happens to want.
(cd $top/shared-install && make $MAKE_ARGS clean)
test -f $top/shared-install/obj/shared/bin/tool-a
test -f $top/shared-install/obj/shared/bin/tool-b

##############################################################################
# Which program bootstraps the tree is worked out by looking at it           #
##############################################################################
# A tree that carries its own bootstrap script carries it because the
# bare autotools commands aren't enough for it -- submodules to pull,
# generated m4 to write, a libtoolize that has to happen in a
# particular order -- so running it is the only thing that can be
# right.  Nothing runs here: what's checked is that pconfigure changed
# its mind about which program to name, and wrote that down where a
# later make can notice the change.
cat >sub/autogen.sh <<'EOF'
#!/bin/sh
exec autoconf
EOF
chmod +x sub/autogen.sh

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
grep -q "cd sub && MY_ENV='one' MY_FLAGS='-O2 -g' ./autogen.sh" Makefile
cat obj/sub/configure-opts
grep -q "^bootstrap ./autogen.sh$" obj/sub/configure-opts

##############################################################################
# A bootstrap that doesn't rewrite the configure still settles              #
##############################################################################
# The fake autoconf at the top of this file rewrites the configure
# every time it runs, which is the one thing a real autoreconf does
# not do: it regenerates the Makefile.in files always and touches
# configure only when configure.ac or aclocal.m4 is newer than it.  So
# a tree whose Makefile.am was edited comes back with the configure it
# already had -- older than the Makefile.am this rule waits on -- and
# unless the rule says otherwise, make runs it again on the next make,
# and the next, dragging a reconfigure and a sub-make behind it every
# time.  That is what this tree is here to catch, and nothing above
# can: the fixture above only ever touches configure.ac.
cat >$fakedir/stale-autoreconf <<EOF
#!/bin/sh
echo "ran" >> $fakedir/stale.log

# The Makefile.in comes back whatever happened, the way automake's
# does.
touch Makefile.in

if [ ! -f configure ] || [ configure.ac -nt configure ]
then
    echo "rewrote" >> $fakedir/stale.log
    cp $fakedir/configure.template ./configure
    chmod +x ./configure
fi
EOF
chmod +x $fakedir/stale-autoreconf

mkdir -p $top/stale/sub
cat >$top/stale/sub/configure.ac <<'EOF'
AC_INIT([stale], [1.0])
AC_CONFIG_FILES([Makefile])
AC_OUTPUT
EOF

# What a Makefile.am says doesn't matter here -- nothing reads it but
# make, which only wants to know when it changed.
cat >$top/stale/sub/Makefile.am <<'EOF'
bin_PROGRAMS = stale
EOF

# printf rather than a heredoc, so that the tab a recipe line has to
# start with is a tab rather than whatever a later edit leaves there.
printf 'srcdir = @srcdir@\nprefix = @prefix@\n\nall:\n\t@echo built > built.txt\n\n.PHONY: all\n' \
    > $top/stale/sub/Makefile.in

{
    echo "BUILD_SYSTEMS += autotools"
    echo ""
    echo "SUBPROJECTS   += sub"
    echo "CONFIGUREOPTS += --autoreconf stale-autoreconf"
    echo "CONFIGUREOPTS += --no-install"
} > $top/stale/Configfile

(cd $top/stale && $PTEST_BINARY $PCONFIGURE_ARGS && make $MAKE_ARGS) \
    > $top/stale-first.out 2>&1
cat $top/stale-first.out
grep -q "AUTORECONF${tab}sub$" $top/stale-first.out
test -f $top/stale/sub/configure

# A Makefile.am is a prerequisite of the bootstrap, so editing one runs
# it -- which is right, and is not the part that was wrong.
sleep 2s
touch $top/stale/sub/Makefile.am
(cd $top/stale && make $MAKE_ARGS) > $top/stale-second.out 2>&1
cat $top/stale-second.out
grep -q "AUTORECONF${tab}sub$" $top/stale-second.out

# And it came back without rewriting the configure, which is what
# makes the make below an assertion about pconfigure rather than about
# the fake: a fake that copied a fresh configure in every time would
# settle no matter what the rule did.
cat $fakedir/stale.log
test "$(grep -c '^rewrote$' $fakedir/stale.log)" = "1"
test "$(grep -c '^ran$' $fakedir/stale.log)" = "2"

# The one that matters: having run the bootstrap once for that edit,
# there is nothing left to do.  Without the rule touching its target
# this prints AUTORECONF here, and on every make after it, forever.
(cd $top/stale && make $MAKE_ARGS) > $top/stale-third.out 2>&1
cat $top/stale-third.out
if grep -q "AUTORECONF" $top/stale-third.out
then
    exit 1
fi
if grep -q "AUTOTOOLS" $top/stale-third.out
then
    exit 1
fi
if grep -q "MAKE${tab}sub$" $top/stale-third.out
then
    exit 1
fi

##############################################################################
# A bootstrap that wrote no configure says so                                #
##############################################################################
# The other half of touching the target: a touch of a file that isn't
# there creates it, and an empty "configure" inside somebody else's
# checkout is both a lie and a file make would call up to date from
# then on.  So the tree is asked whether the bootstrap actually
# produced anything, and a bootstrap that didn't is a build that stops
# here rather than one that gets as far as trying to run it.
#
# One tree per bootstrap command, built as far as the place where it
# stops.  What the command is differs from caller to caller and what
# it does never does: it runs, it succeeds, and it writes no
# configure, so the only thing that can have stopped the build is the
# check this section is about.
bootstraps_nothing()
{
    mkdir -p $top/$1/sub
    touch $top/$1/sub/configure.ac

    {
        echo "BUILD_SYSTEMS += autotools"
        echo ""
        echo "SUBPROJECTS   += sub"
        echo "CONFIGUREOPTS += --autoreconf $2"
    } > $top/$1/Configfile
    cat $top/$1/Configfile

    (cd $top/$1 && $PTEST_BINARY $PCONFIGURE_ARGS)
    if (cd $top/$1 && make $MAKE_ARGS) > $top/$1.out 2>&1
    then
        exit 1
    fi
    cat $top/$1.out

    # Every one of these stops the build, so "make failed" is a thing
    # this test can't learn anything from -- including whether the
    # recipe was something a shell could read at all.  A bootstrap
    # command is a shell command and so may have quotes in it, and a
    # diagnostic that pasted those into a quoted string of its own is
    # a recipe the shell gives up on before printing a word of it.
    # That fails too, with make's error and none of the advice, which
    # from a test that only checks that make stopped is
    # indistinguishable from the thing working.
    if grep -qi "syntax error" $top/$1.out
    then
        exit 1
    fi
    if grep -q "unexpected EOF" $top/$1.out
    then
        exit 1
    fi

    # And nothing was left in the tree, which is the thing the check
    # is for: the file make would have believed in is the file that
    # isn't there.
    test ! -e $top/$1/sub/configure
}

bootstraps_nothing no-bootstrap "true"
grep -q "wrote no 'sub/configure'" $top/no-bootstrap.out
grep -q -- "--autoreconf CMD" $top/no-bootstrap.out

# A bootstrap command with quotes in it, which is a shape the option
# has to allow: the guess handles the trees whose bootstrap is one
# word, so an --autoreconf gets written for the ones where it is a
# line of shell.  The command comes back spelled the way the
# Configfile spelled it, because a message about a line has to name
# that line in the words that are on it -- and because the only way
# to lose those quotes is to have handed them to a shell as quoting,
# which is the mistake below wearing a hat.
bootstraps_nothing quoted-bootstrap 'sh -c "exit 0"'
grep -q "'sh -c \"exit 0\"' in 'sub' wrote no 'sub/configure'" \
    $top/quoted-bootstrap.out
if grep -q "'sh -c exit 0'" $top/quoted-bootstrap.out
then
    exit 1
fi

# And the same thing with an odd number of them, which is where it
# stops being about the spelling.  This command is a perfectly good
# one -- the line above it in the recipe runs it and it succeeds --
# but its quote, pasted into a diagnostic that quotes with the same
# character, ends that diagnostic's own quoting and leaves the rest of
# the recipe as whatever the shell makes of it.  What comes out then
# is a syntax error from a line whose entire job was to explain a
# mistake.
bootstraps_nothing odd-quote "sed -n 's|x|\"|p' configure.ac"
grep -q "wrote no 'sub/configure'" $top/odd-quote.out
grep -q "sed -n 's|x|\"|p' configure.ac" $top/odd-quote.out
grep -q -- "--autoreconf CMD" $top/odd-quote.out

# A '$' in the command is make's before it is any shell's, since make
# expands a recipe before handing it over.  The message is about what
# a Configfile says, so it says what the Configfile says: unescaped,
# "$PATH" reaches the terminal as "ATH" -- make having read "$P" as a
# variable nobody set -- and an expansion that came back with a quote
# in it would be back to the line above.
bootstraps_nothing dollar-bootstrap "sh -c 'echo \$PATH > /dev/null'"
grep -q "'sh -c 'echo \$PATH > /dev/null'' in 'sub'" $top/dollar-bootstrap.out
if grep -q "echo ATH" $top/dollar-bootstrap.out
then
    exit 1
fi

##############################################################################
# --autoreconf and --no-autoreconf are one setting, last one wins            #
##############################################################################
# The shape somebody writes is a "--no-autoreconf" under BUILD_SYSTEMS,
# which every autotools subproject inherits, and an "--autoreconf" under
# the one SUBPROJECTS that does have to be bootstrapped.  Read in the
# order they were written, that says what it looks like it says.  Read
# by asking about "--no-autoreconf" first, the second line does
# nothing at all and the tree is refused for having no configure and
# nothing to make one -- advice about an option the author did write.
#
# The program the option names is one no guess could have arrived at,
# which is what makes this an assertion about the option rather than
# about the tree: an "autogen.sh" here would be what this build system
# picks by looking, whether the line was read or not.
mkdir -p $top/last-wins/sub
cat >$top/last-wins/sub/configure.ac <<'EOF'
AC_INIT([last], [1.0])
AC_OUTPUT
EOF
cat >$top/last-wins/sub/rebuild-me <<'EOF'
#!/bin/sh
exec autoconf
EOF
chmod +x $top/last-wins/sub/rebuild-me

{
    echo "BUILD_SYSTEMS += autotools"
    echo "CONFIGUREOPTS += --no-autoreconf"
    echo ""
    echo "SUBPROJECTS   += sub"
    echo "CONFIGUREOPTS += --autoreconf ./rebuild-me"
} > $top/last-wins/Configfile
cat $top/last-wins/Configfile

(cd $top/last-wins && $PTEST_BINARY $PCONFIGURE_ARGS)
cat $top/last-wins/Makefile
grep -q "^sub/configure:" $top/last-wins/Makefile
grep -q "cd sub && ./rebuild-me" $top/last-wins/Makefile
grep -q "^bootstrap ./rebuild-me$" $top/last-wins/obj/sub/configure-opts

# And the other order means the other thing, which is what keeps this
# from being "--autoreconf always wins" written the long way: a
# "--no-autoreconf" after one leaves a tree with a configure.ac and no
# configure, which is refused rather than built halfway.
mkdir -p $top/last-wins-off/sub
cp $top/last-wins/sub/configure.ac $top/last-wins-off/sub/configure.ac

{
    echo "BUILD_SYSTEMS += autotools"
    echo ""
    echo "SUBPROJECTS   += sub"
    echo "CONFIGUREOPTS += --autoreconf ./rebuild-me"
    echo "CONFIGUREOPTS += --no-autoreconf"
} > $top/last-wins-off/Configfile
cat $top/last-wins-off/Configfile

if (cd $top/last-wins-off && $PTEST_BINARY $PCONFIGURE_ARGS) \
    > $top/last-wins-off.out 2>&1
then
    exit 1
fi
cat $top/last-wins-off.out
grep -q "there is no 'sub/configure' to run" $top/last-wins-off.out
test ! -e $top/last-wins-off/Makefile

##############################################################################
# A --target is one target, whatever is written in it                        #
##############################################################################
# One option is one target: a tree that wants two of them writes
# --target twice, and they are asked for one at a time in the order
# they were given.  So whatever is inside one of them is characters of
# a name, and what the sub-make gets is one word -- which is what
# every other value a CONFIGUREOPTS writes gets on its way into a
# recipe, and this one used to be the exception.
#
# Left raw, a semicolon in a target ends the recipe's command and the
# shell runs the rest of the line as a program of its own: a
# Configfile read without a murmur at configure time, a build that
# quietly does something nobody wrote down, and a tree asked for a
# target that is not the one the line names.  The tree here has no
# rule for the whole word, so this build is meant to fail -- what says
# the target arrived whole is that make was stopped by the name rather
# than running the tail of it.
mkdir -p $top/one-target/sub
cp $fakedir/configure.template $top/one-target/sub/configure
chmod +x $top/one-target/sub/configure

# printf rather than a heredoc, so that the tab a recipe line has to
# start with is a tab rather than whatever a later edit leaves there.
printf 'srcdir = @srcdir@\nprefix = @prefix@\n\nhello:\n\t@echo built > built.txt\n\n.PHONY: hello\n' \
    > $top/one-target/sub/Makefile.in

{
    echo "BUILD_SYSTEMS += autotools"
    echo ""
    echo "SUBPROJECTS   += sub"
    echo "CONFIGUREOPTS += --no-install"
    echo "CONFIGUREOPTS += --target hello; echo ran > $top/one-target/ran.txt"
} > $top/one-target/Configfile
cat $top/one-target/Configfile

(cd $top/one-target && $PTEST_BINARY $PCONFIGURE_ARGS)
if (cd $top/one-target && make $MAKE_ARGS) > $top/one-target.out 2>&1
then
    exit 1
fi
cat $top/one-target.out

# The whole word reached the sub-make as the name of one target, which
# that tree hasn't got.
grep -q "hello; echo ran" $top/one-target.out

# And the tail of it was never run as a command of its own, which is
# the thing this is really about.
test ! -e $top/one-target/ran.txt

##############################################################################
# Options that can't mean anything                                           #
##############################################################################
# Each of these is a Configfile with one line in it that doesn't say
# what somebody meant, and what's checked is what pconfigure said
# about it rather than merely that it stopped -- including the advice,
# since a diagnostic nobody asserts on is a diagnostic that rots.
#
# The subshell is the assertion: "set -e" is on, so a command expected
# to fail has to be somewhere a failure isn't fatal.
refuses()
{
    mkdir -p $top/$1/sub
    touch $top/$1/sub/configure.ac

    {
        echo "BUILD_SYSTEMS += autotools"
        echo ""
        echo "SUBPROJECTS   += sub"
        echo "CONFIGUREOPTS += $2"
    } > $top/$1/Configfile
    cat $top/$1/Configfile

    if (cd $top/$1 && $PTEST_BINARY $PCONFIGURE_ARGS) > $top/$1.out 2>&1
    then
        exit 1
    fi
    cat $top/$1.out

    # A configure that stopped wrote no Makefile.  Half a Makefile is
    # worse than none at all, since make would go ahead and use it.
    test ! -e $top/$1/Makefile
}

# A configure variable without a value is a word configure reads as a
# flag it has never heard of, and configure's answer to a flag it has
# never heard of is a warning and a build that carries on without it.
refuses bad-var "--configure-var YACC"
grep -q "'--configure-var YACC' has no value" $top/bad-var.out
grep -q "'--configure-var YACC=/opt/bin/bison'" $top/bad-var.out

# And the same mistake the other way round, which is the one somebody
# actually makes: the two options exist so that this can be caught.
refuses bad-flag "--configure-flag enable-extra"
grep -q "'--configure-flag enable-extra' isn't a flag" $top/bad-flag.out
grep -q "is a '--configure-var' instead" $top/bad-flag.out

# What a legal install prefix is has exactly one statement and one
# place it is enforced: a directory inside the object directory of the
# project that vendored the tree, named relative to that project.  See
# build_system::install_dir().  Everything from here to the end of this
# block is one of the three ways of not being that, and each of them is
# here because deleting the check that catches it leaves the rest of
# this file green.

# Absolute.  The install here happens during "make" rather than during
# "make install", because whatever is vendored is vendored so the rest
# of the build can use it -- so a plain "make" that writes into
# /usr/local is not a thing to let somebody ask for by accident, and
# the accident is one character long.  An absolute path is also the one
# shape no Makefile here can rewrite for a build run from somewhere
# else.
refuses bad-prefix "--prefix /opt/toolchain"
grep -q "'--prefix /opt/toolchain' is an absolute path" $top/bad-prefix.out
grep -q "like '--prefix obj/toolchain'" $top/bad-prefix.out

# Outside the object directory.  "tools" here is a directory of the
# project's own, and that is exactly what makes it the wrong answer:
# what is under it is the project's, checked in, and an install prefix
# is a directory a build gets to own outright.
refuses outside-obj "--prefix tools/prefix"
grep -q "'--prefix tools/prefix' names 'tools/prefix', which is outside 'obj'" \
    $top/outside-obj.out
grep -q "write a directory inside 'obj', like '--prefix obj/toolchain'" \
    $top/outside-obj.out

# The vendored tree is one of the places "outside the object
# directory" covers, and the one somebody reaches for: it is beside
# the Configfile and it is where the tree is.  It is also somebody
# else's checkout, so a build that installed in there would turn up as
# a dirty submodule in a repository this project does not own.
refuses into-tree "--prefix sub/stage"
grep -q "which is outside 'obj'" $top/into-tree.out

# And a directory whose name merely starts with the object
# directory's, which is the case a check written as "the path starts
# with 'obj'" lets through.  It is outside the object directory: the
# character after "obj" has to be a '/' for anything to be inside it.
refuses objish "--prefix objects/stage"
grep -q "names 'objects/stage', which is outside 'obj'" $top/objish.out

# The object directory itself, which is inside itself and is still not
# a directory inside it.  cache-clean spares an install prefix, so a
# prefix that is the whole object directory is a cache-clean that
# reclaims nothing at all -- and says nothing about it, since it runs
# and finishes exactly as it would have.
refuses obj-itself "--prefix obj"
grep -q "'--prefix obj' is the object directory itself" $top/obj-itself.out
grep -q "make cache-clean" $top/obj-itself.out
grep -q "like '--prefix obj/toolchain'" $top/obj-itself.out

# The project itself, written the shortest way there is.  It is
# outside the object directory rather than above it, which is the same
# refusal: a prefix that was the checkout would be a directory nothing
# in it was installed into.
refuses dot-prefix "--prefix ."
grep -q "names '.', which is outside 'obj'" $top/dot-prefix.out

# And one directory further up, which is a different refusal and the
# one that matters most: the directory the project was checked out
# into holds the project and whatever else is beside it.  It is here
# rather than left to the "../" case below because a bare ".." has no
# trailing slash on it, so a check looking for a path that starts with
# "../" sees nothing to match and lets through the worst prefix there
# is.
refuses up-prefix "--prefix .."
grep -qF "'--prefix ..' reaches outside the project that wrote it" \
    $top/up-prefix.out
grep -q "like '--prefix obj/toolchain'" $top/up-prefix.out

# And the same thing with the slash on it, which is what the check
# above would have caught on its own.  Both spellings, because a check
# for one of them is a check for one of them.
refuses up-slash-prefix "--prefix ../outside"
grep -qF "'--prefix ../outside' reaches outside the project that wrote it" \
    $top/up-slash-prefix.out

# Inside the object directory and inside the part of it this project
# builds into itself.  Owning every byte of an object directory is
# what lets a prefix be in there at all; it is not the same as having
# none of it spoken for.  "obj/src" is where the objects this project
# compiles land, and "make cache-clean" spares an install prefix whole
# -- so a prefix here is a cache-clean that reclaims none of the cache
# it exists to reclaim, and says nothing about it, since it runs and
# finishes exactly as it would have.
refuses own-obj-src "--prefix obj/src"
grep -q "'--prefix obj/src' names 'obj/src', which is where this project builds" \
    $top/own-obj-src.out
grep -q "make cache-clean" $top/own-obj-src.out
grep -q "like '--prefix obj/toolchain'" $top/own-obj-src.out

# And the same for the directory a GENERATE writes into, which is the
# other one somebody reaches for by accident: it is not named after
# anything in the Configfile, so it looks like free space.
refuses own-obj-proc "--prefix obj/proc"
grep -q "names 'obj/proc', which is where this project builds" \
    $top/own-obj-proc.out

# A prefix with one of those inside it rather than the other way
# round, which spares that one along with everything else it holds.
# The object directory itself is refused a line earlier for its own
# reasons, so saying this needs a project whose own output lands
# somewhere deeper than one directory down.
mkdir -p $top/over-obj/sub $top/over-obj/nest/deeper
cp $fakedir/configure.template $top/over-obj/sub/configure
chmod +x $top/over-obj/sub/configure
{
    echo "SRCDIR         = nest/deeper"
    echo ""
    echo "BUILD_SYSTEMS += autotools"
    echo ""
    echo "SUBPROJECTS   += sub"
    echo "CONFIGUREOPTS += --prefix obj/nest"
} > $top/over-obj/Configfile
cat $top/over-obj/Configfile

if (cd $top/over-obj && $PTEST_BINARY $PCONFIGURE_ARGS) \
    > $top/over-obj.out 2>&1
then
    exit 1
fi
cat $top/over-obj.out
grep -q "names 'obj/nest', which is where this project builds" \
    $top/over-obj.out
grep -q "'obj/nest/deeper' is pconfigure's own" $top/over-obj.out
test ! -e $top/over-obj/Makefile

# Which of those directories they are is read off this project rather
# than written out as a list of names, and this is what says so: a
# project that moved its SRCDIR moved where its objects land, so
# "obj/src" stops being spoken for and "obj/elsewhere" starts.  A list
# of literals would be right for the default project and quietly wrong
# for this one, in both directions at once.
mkdir -p $top/moved-src/sub $top/moved-src/elsewhere
cp $fakedir/configure.template $top/moved-src/sub/configure
chmod +x $top/moved-src/sub/configure
{
    echo "SRCDIR         = elsewhere"
    echo ""
    echo "BUILD_SYSTEMS += autotools"
    echo ""
    echo "SUBPROJECTS   += sub"
    echo "CONFIGUREOPTS += --prefix obj/src"
} > $top/moved-src/Configfile
(cd $top/moved-src && $PTEST_BINARY $PCONFIGURE_ARGS)
grep -q -- "'--prefix=\$(abspath obj/src)'" $top/moved-src/Makefile

sed -i.bak 's|--prefix obj/src|--prefix obj/elsewhere|' \
    $top/moved-src/Configfile
cat $top/moved-src/Configfile
if (cd $top/moved-src && $PTEST_BINARY $PCONFIGURE_ARGS) \
    > $top/moved-src.out 2>&1
then
    exit 1
fi
cat $top/moved-src.out
grep -q "names 'obj/elsewhere', which is where this project builds" \
    $top/moved-src.out

# A prefix inside the object directory and outside this tree's own
# output directory is the shape the option exists for: several trees
# landing in one place.  "obj/shared" is that shape, and it is built,
# cache-cleaned and distcleaned in the fixture at the top of this file.
mkdir -p $top/obj-prefix/sub
cp $fakedir/configure.template $top/obj-prefix/sub/configure
chmod +x $top/obj-prefix/sub/configure
{
    echo "BUILD_SYSTEMS += autotools"
    echo ""
    echo "SUBPROJECTS   += sub"
    echo "CONFIGUREOPTS += --prefix obj/stage"
} > $top/obj-prefix/Configfile
(cd $top/obj-prefix && $PTEST_BINARY $PCONFIGURE_ARGS)
grep -q -- "'--prefix=\$(abspath obj/stage)'" $top/obj-prefix/Makefile

# And a prefix inside this tree's own output directory is fine too,
# since that is the part of the object directory cache-clean spares
# for its own reasons -- which is the whole reason the default one is
# in there.
mkdir -p $top/own-prefix/sub
cp $fakedir/configure.template $top/own-prefix/sub/configure
chmod +x $top/own-prefix/sub/configure
{
    echo "BUILD_SYSTEMS += autotools"
    echo ""
    echo "SUBPROJECTS   += sub"
    echo "CONFIGUREOPTS += --prefix obj/sub/staged"
} > $top/own-prefix/Configfile
(cd $top/own-prefix && $PTEST_BINARY $PCONFIGURE_ARGS)
grep -q -- "'--prefix=\$(abspath obj/sub/staged)'" $top/own-prefix/Makefile

# And a tree told not to install, which has no install prefix at all
# even though a --prefix beside it says where one would have gone.
# The option still reaches configure, because a tree gets to be
# configured with a prefix it never installs into; what it does not
# do is name a directory for cache-clean to spare.  Sparing one would
# cost a build nothing -- the directory is never made, so there is
# never anything in it to reclaim -- which is exactly why it goes
# unnoticed unless it is asked about outright.
mkdir -p $top/no-install-prefix/sub
cp $fakedir/configure.template $top/no-install-prefix/sub/configure
chmod +x $top/no-install-prefix/sub/configure
{
    echo "BUILD_SYSTEMS += autotools"
    echo ""
    echo "SUBPROJECTS   += sub"
    echo "CONFIGUREOPTS += --prefix obj/shared"
    echo "CONFIGUREOPTS += --no-install"
} > $top/no-install-prefix/Configfile
(cd $top/no-install-prefix && $PTEST_BINARY $PCONFIGURE_ARGS)
grep -q -- "'--prefix=\$(abspath obj/shared)'" $top/no-install-prefix/Makefile
if grep -q -- "-not -path 'obj/shared/[*]'" $top/no-install-prefix/Makefile
then
    exit 1
fi

##############################################################################
# A prefix with a quote in it is a path, not a syntax error                  #
##############################################################################
# Where a prefix is allowed to point is asked about exhaustively above;
# what it is allowed to be spelled with is asked here.  A directory
# whose name has an apostrophe in it is a perfectly good directory, and
# whose checkout is under one is none of pconfigure's business -- but
# the prefix is the one argument on configure's command line whose
# value came out of a Configfile, and it is pasted into a shell
# command.  Wrapped in a pair of quotes written by hand, an apostrophe
# in there closes the argument early and leaves the shell reading the
# rest of the recipe for a quote that never comes: a line accepted
# without a murmur at configure time and a build that dies saying
# "unexpected EOF" about a recipe nobody wrote.
#
# The tree's own install rule quotes with double quotes, which is the
# fixture's business rather than pconfigure's: a tree that can't
# install into a prefix with a quote in it has a bug of its own, and
# what is under test here is the argument pconfigure handed it.
mkdir -p $top/quoted-prefix/sub
cp $fakedir/configure.template $top/quoted-prefix/sub/configure
chmod +x $top/quoted-prefix/sub/configure
cat >$top/quoted-prefix/sub/Makefile.in <<'EOF'
srcdir = @srcdir@
prefix = @prefix@

all:
	@echo built > built.txt

install: all
	@mkdir -p "$(prefix)/bin"
	@cp built.txt "$(prefix)/bin/tool"

.PHONY: all install
EOF
{
    echo "BUILD_SYSTEMS += autotools"
    echo ""
    echo "SUBPROJECTS   += sub"
    echo "CONFIGUREOPTS += --prefix obj/it's-stage"
} > $top/quoted-prefix/Configfile
cat $top/quoted-prefix/Configfile

(cd $top/quoted-prefix && $PTEST_BINARY $PCONFIGURE_ARGS)

# The quote is closed and reopened around itself rather than left to
# end the argument, which is the whole of what string_utils::quoted()
# does that a pair of quotes written by hand does not.
grep -q -F -- "'--prefix=\$(abspath obj/it'\\''s-stage)'" \
    $top/quoted-prefix/Makefile

(cd $top/quoted-prefix && make $MAKE_ARGS)

# One line in the file configure wrote down is one argument it was
# handed, apostrophe and all: split in half, this would be a prefix
# nobody asked for followed by a word configure read as a flag of its
# own.
cat "$top/quoted-prefix/obj/sub/build/configure.args"
grep -q "^--prefix=/.*/obj/it's-stage$" \
    "$top/quoted-prefix/obj/sub/build/configure.args"

# And the install landed in the directory the Configfile named.
test -f "$top/quoted-prefix/obj/it's-stage/bin/tool"

##############################################################################
# Several trees, one prefix                                                  #
##############################################################################
# Which is the reason a --prefix exists, so the two things that go
# wrong when it is used that way are worth saying outright.
#
# The first is bookkeeping: cache-clean has to spare the shared
# directory once rather than once per tree.  Saying it twice would
# work and would make a command that is already too long to read
# longer, so the count is the assertion.
mkdir -p $top/two-trees/a $top/two-trees/b
cp $fakedir/configure.template $top/two-trees/a/configure
cp $fakedir/configure.template $top/two-trees/b/configure
chmod +x $top/two-trees/a/configure $top/two-trees/b/configure
{
    echo "BUILD_SYSTEMS += autotools"
    echo ""
    echo "SUBPROJECTS   += a"
    echo "CONFIGUREOPTS += --prefix obj/shared"
    echo ""
    echo "SUBPROJECTS   += b"
    echo "CONFIGUREOPTS += --prefix obj/shared"
} > $top/two-trees/Configfile
(cd $top/two-trees && $PTEST_BINARY $PCONFIGURE_ARGS)

# Two commands make up a cache-clean -- one that removes files and one
# that removes the directories they were in -- and the prune goes on
# both, so once per tree would be four.  Counted with "-o" rather than
# with "-c", since both of those clauses are on one line each and a
# count of lines would say two either way.
grep -o -- "-not -path 'obj/shared/[*]'" $top/two-trees/Makefile \
    | wc -l | tr -d ' ' > shared-prunes
cat shared-prunes
test "$(cat shared-prunes)" = "2"

# The second is a collision that make reports and nobody reads.  Both
# trees install into one directory, so two SUBPROJECT_TARGETS naming
# one path inside it are two rules for one target: make keeps the last
# one and warns in the middle of a build.  Which tree really builds
# the file is not something pconfigure can work out, so it says so and
# stops.
mkdir -p $top/collide/a $top/collide/b
cp $fakedir/configure.template $top/collide/a/configure
cp $fakedir/configure.template $top/collide/b/configure
chmod +x $top/collide/a/configure $top/collide/b/configure
{
    echo "BUILD_SYSTEMS += autotools"
    echo ""
    echo "SUBPROJECTS   += a"
    echo "CONFIGUREOPTS += --prefix obj/shared"
    echo "SUBPROJECT_TARGETS += bin/tool"
    echo ""
    echo "SUBPROJECTS   += b"
    echo "CONFIGUREOPTS += --prefix obj/shared"
    echo "SUBPROJECT_TARGETS += bin/tool"
} > $top/collide/Configfile

if (cd $top/collide && $PTEST_BINARY $PCONFIGURE_ARGS) > $top/collide.out 2>&1
then
    exit 1
fi
cat $top/collide.out
grep -q "'obj/shared/bin/tool' is named by a SUBPROJECT_TARGETS under 'a'" \
    $top/collide.out
grep -q "and by one under 'b'" $top/collide.out
grep -q "two recipes for one target" $top/collide.out
test ! -e $top/collide/Makefile

# The same two trees without the collision configure quite happily,
# which is what says the refusal above is about the two names rather
# than about the shared prefix.
{
    echo "BUILD_SYSTEMS += autotools"
    echo ""
    echo "SUBPROJECTS   += a"
    echo "CONFIGUREOPTS += --prefix obj/shared"
    echo "SUBPROJECT_TARGETS += bin/tool-a"
    echo ""
    echo "SUBPROJECTS   += b"
    echo "CONFIGUREOPTS += --prefix obj/shared"
    echo "SUBPROJECT_TARGETS += bin/tool-b"
} > $top/collide/Configfile
(cd $top/collide && $PTEST_BINARY $PCONFIGURE_ARGS)
grep -q "^obj/shared/bin/tool-a: obj/a/build-stamp$" $top/collide/Makefile
grep -q "^obj/shared/bin/tool-b: obj/b/build-stamp$" $top/collide/Makefile

##############################################################################
# Where the tree installs is said once, or not at all                        #
##############################################################################
# A --prefix is checked -- everything above this is that check -- and
# it is the only thing the rest of the build reads: cache-clean spares
# that directory, distclean takes it, and a SUBPROJECT_TARGETS is
# named relative to it.  So a second answer given some other way is
# not a different spelling of the same statement, it is a tree that
# installs where nothing goes looking.
#
# And the install here runs during "make" rather than during "make
# install", because whatever is vendored is vendored so the rest of
# the build can use it.  What is on the other side of each of these is
# a plain "make" writing wherever the line pointed, and "/usr/local"
# is one character away from every one of them.
#
# Four channels reach the tree and every one of them is taken below:
# configure's flags, a variable on configure's command line, a
# variable on the command line of the make that installs, and the
# environment that make imports its variables from in the first place.
# One of each spelling, since it is the spelling rather than the
# variable that decides whether a check sees it.
installs_elsewhere()
{
    refuses $1 "$2"
    grep -q "says where the tree installs to" $top/$1.out
    grep -q "write '--prefix DIR' instead" $top/$1.out
}

# Among configure's flags, which is the spelling the old check watched
# -- and it watched only "--prefix", so a "--bindir" sailed through
# and a plain "make" installed into /usr/local/bin.
installs_elsewhere flag-prefix "--configure-flag --prefix=/usr/local"

# autoconf spells its options with dashes and its variables with
# underscores, and "--exec-prefix" and "exec_prefix" are one thing.
# Setting it alone moves the programs and the libraries without
# touching the prefix, so a check that only read "prefix" would see
# nothing wrong with this line at all.
installs_elsewhere flag-exec-prefix "--configure-flag --exec-prefix=/usr"

# As a variable on configure's command line, which a generated
# configure reads as an assignment whatever the name is.
installs_elsewhere var-prefix "--configure-var prefix=/usr/local"

# And on the command line of the make that installs, where a variable
# beats whatever the tree's own Makefile says about it -- which is the
# whole reason to write one.
#
# The diagnostic has to name the option that was written rather than
# the MAKEOPS it is the same as, and that is asserted here because it
# is the only thing that pins the check on this path: a --make-var
# reaches take_makeopt() as well, so deleting the check where the
# option is read leaves the line refused and the message pointing at a
# line nobody wrote.
installs_elsewhere make-var-prefix "--make-var prefix=/usr/local"
grep -q "'--make-var prefix=/usr/local' sets 'prefix'" \
    $top/make-var-prefix.out

# DESTDIR is make's rather than autoconf's and belongs with them for
# the same reason: it is pasted onto the front of every one of the
# others while the install is running.
installs_elsewhere make-var-destdir "--make-var DESTDIR=/tmp/stage"
grep -q "'--make-var DESTDIR=/tmp/stage' sets 'DESTDIR'" \
    $top/make-var-destdir.out

# And the fourth spelling of DESTDIR, which is the environment -- the
# channel make imports a variable from in the first place.  It was
# refused in the three above and taken here, which is worse than never
# having refused it at all: three closed doors and an open one read as
# a closed door, and what came through this one was the whole install,
# staged wherever it pointed, on a plain "make".
installs_elsewhere env-destdir "--env DESTDIR=/tmp/stage"
grep -q "'--env DESTDIR=/tmp/stage' sets 'DESTDIR'" $top/env-destdir.out

# And the same variable written as the MAKEOPS it is the same as,
# which is a different line of Configfile and reaches the sub-make
# through a different door.
mkdir -p $top/makeops-prefix/sub
touch $top/makeops-prefix/sub/configure.ac
{
    echo "BUILD_SYSTEMS += autotools"
    echo ""
    echo "SUBPROJECTS   += sub"
    echo "MAKEOPS       += prefix=/usr/local"
} > $top/makeops-prefix/Configfile
cat $top/makeops-prefix/Configfile

if (cd $top/makeops-prefix && $PTEST_BINARY $PCONFIGURE_ARGS) \
    > $top/makeops-prefix.out 2>&1
then
    exit 1
fi
cat $top/makeops-prefix.out
grep -q "says where the tree installs to" $top/makeops-prefix.out
test ! -e $top/makeops-prefix/Makefile

##############################################################################
# And the shortened spellings, which are the same options              #
##############################################################################
# autoconf writes out every truncation of every option name it takes,
# down to whatever is still unambiguous: the generated configure's own
# case statement reads
#
#   -prefix | --prefix | --prefi | --pref | --pre | --pr | --p)
#
# so all seven of those are "--prefix", and "--bi=" is "--bindir=".  A
# check that matched whole names refused "--prefix=/usr/local" and
# accepted "--pre=/usr/local", which is the same line with three
# characters taken off it -- and a real configure installed exactly
# where it said.
#
# What catches them is that the name written is a prefix of a name on
# the list, which is the shape of the thing rather than a longer list.
shortened()
{
    refuses $1 "$2"
    grep -q "sets '$3'" $top/$1.out
}

shortened short-p "--configure-flag --p=/usr/local" prefix
shortened short-pr "--configure-flag --pr=/usr/local" prefix
shortened short-pre "--configure-flag --pre=/usr/local" prefix
shortened short-prefi "--configure-flag --prefi=/usr/local" prefix
shortened short-ex "--configure-flag --ex=/usr" exec_prefix
shortened short-bi "--configure-flag --bi=/usr/local/bin" bindir
shortened short-bin "--configure-flag --bin=/usr/local/bin" bindir
shortened short-libd "--configure-flag --libd=/usr/local/lib" libdir

# And the single-dash spelling, which a generated configure takes for
# the whole name and for nothing shorter.  That is why the shortening
# above is asked only of the "--" spelling: a single-dash "-d" is not
# an abbreviation of anything, and refusing it as one would be
# refusing a flag that has nothing to do with where anything installs.
shortened dash-prefix "--configure-flag -prefix=/usr/local" prefix
shortened dash-bindir "--configure-flag -bindir=/usr/local/bin" bindir

# And the same name with a backslash through it.  Everything a
# --configure-flag says is quoted on its way into the recipe, so this
# one is the shell's quoting reaching the check rather than reaching
# the tree -- but the word is read the way the tree would read it
# either way, because one of these build systems does hand a word over
# raw and a rule that held in one of them and not the other is a rule
# nobody can state.
shortened escaped-prefix "--configure-flag -\\-prefix=/usr/local" prefix

# The two-word form, which a generated configure also accepts: the
# directory is in the next argument, so this word is the whole of what
# there is to catch.  Shortened as well, since that is how it arrives.
shortened split-libdir "--configure-flag --libdir" libdir
shortened split-short "--configure-flag --libd" libdir

##############################################################################
# Where part of the install goes is the same question one level down   #
##############################################################################
# The GNU directory variables say where one kind of file lands rather
# than where the install as a whole does.  Every one of them still
# moves files, and an absolute one moves them out from under the
# prefix entirely -- so the programs go to /usr/local/bin with the
# prefix left exactly as this build system wrote it.
#
# What the diagnostic may not do is offer "--prefix DIR" as the same
# thing said another way, because it isn't: a --prefix cannot say
# "bindir".  So these say what they refuse and why, and the advice
# they give is the true one -- the layout under the prefix is the
# tree's own business.
moves_the_install()
{
    refuses $1 "$2"
    grep -q "sets '$3', which says where part of the install goes" \
        $top/$1.out
    grep -q "a relative value is no way round it here" $top/$1.out
    grep -q "write '--prefix DIR', which moves the whole install" \
        $top/$1.out
}

moves_the_install flag-bindir "--configure-flag --bindir=/usr/local/bin" \
    bindir
moves_the_install var-libdir "--configure-var libdir=/usr/local/lib" libdir
moves_the_install make-var-bindir "--make-var bindir=/usr/local/bin" bindir

# And a relative one, which is refused here rather than accepted with
# the prefix stuck on the front of it.  It reaches the tree's own
# Makefile exactly as it was written and the install rule reads it
# from the directory make is standing in, which is the build directory
# -- so "bin" is a tree installing into its own build directory and a
# SUBPROJECT_TARGETS naming a file that never appears.  cmake joins a
# relative one to the prefix and so takes it; this doesn't, and the
# difference is written down in each build system's already_answered().
moves_the_install relative-bindir "--configure-flag --bindir=bin" bindir

##############################################################################
# Which tree gets configured is said once too                                #
##############################################################################
# The install escape one option across.  configure works out where its
# sources are from the path it was run as -- which is why pconfigure
# runs "$(abspath sub)/configure" -- and "--srcdir" is that said a
# second time, about a tree no SUBPROJECTS ever named.  What comes of
# it is a build of somebody else's directory under this subproject's
# name, configured and installed without a word.
said_twice()
{
    refuses $1 "$2"
    grep -q "sets '$3', which says which tree gets configured" $top/$1.out
    grep -q "a SUBPROJECTS says which tree gets built" $top/$1.out
}

said_twice srcdir-flag "--configure-flag --srcdir=/tmp/other-tree" srcdir
said_twice srcdir-short "--configure-flag --src=/tmp/other-tree" srcdir
said_twice srcdir-var "--configure-var srcdir=/tmp/other-tree" srcdir

##############################################################################
# Where configure caches what it found out is a place too                    #
##############################################################################
# A generated configure's "--cache-file=PATH" -- or the bare
# "cache_file=PATH" variable, which is the same statement without the
# dashes -- both creates and overwrites the file at PATH once configure
# has run, which is real behaviour of a real autoconf rather than a
# hazard borrowed from somewhere else: confirmed against autoconf 2.73
# by hand, pointed at a scratch path under this machine's own tmp and
# nowhere real.  Left unrefused, a Configfile that wrote one of these
# writes over a file at wherever the line pointed on every configure --
# outside this project's object directory as readily as inside it, and
# "make distclean" never hears about either.
caches_the_wrong_place()
{
    refuses $1 "$2"
    grep -q "sets '$3', which says where the tree caches what configure" \
        $top/$1.out
    grep -q "found out" $top/$1.out
    grep -q "a SUBPROJECTS says which tree gets built" $top/$1.out
}

caches_the_wrong_place cache-file-flag \
    "--configure-flag --cache-file=/tmp/elsewhere.cache" cache_file
caches_the_wrong_place cache-file-var \
    "--configure-var cache_file=/tmp/elsewhere.cache" cache_file

# The dashed spelling reaches a sub-make's command line just as
# readily as it reaches configure's, and MAKEOPS hands a word straight
# to that command line without stripping a decoration off it first --
# so the dashed name is refused on its own, rather than only once it
# has been folded into the underscored one configure actually reads.
mkdir -p $top/cache-file-makeops/sub
touch $top/cache-file-makeops/sub/configure.ac
{
    echo "BUILD_SYSTEMS += autotools"
    echo ""
    echo "SUBPROJECTS   += sub"
    echo "MAKEOPS       += cache-file=/tmp/elsewhere.cache"
} > $top/cache-file-makeops/Configfile
cat $top/cache-file-makeops/Configfile
if (cd $top/cache-file-makeops && $PTEST_BINARY $PCONFIGURE_ARGS) \
    > $top/cache-file-makeops.out 2>&1
then
    exit 1
fi
cat $top/cache-file-makeops.out
grep -q "sets 'cache-file', which says where the tree caches what configure" \
    $top/cache-file-makeops.out
test ! -e $top/cache-file-makeops/Makefile

# An option whose name merely starts with one of those is not one of
# them.  "--with-sysroot" and "--sbindir" look identical from a
# distance, which is why the list is written out rather than matched
# by shape -- and a check that took this line would be refusing an
# option somebody had every right to write.
#
# The two here are the two directions a name can miss by: one that has
# a refused name as its own prefix, which is what the shortening rule
# above would take if it were read backwards, and one that merely
# looks like a refused name from a distance.
mkdir -p $top/near-miss/sub
cp $fakedir/configure.template $top/near-miss/sub/configure
chmod +x $top/near-miss/sub/configure
{
    echo "BUILD_SYSTEMS += autotools"
    echo ""
    echo "SUBPROJECTS   += sub"
    echo "CONFIGUREOPTS += --configure-flag --prefix-map=a=b"
    echo "CONFIGUREOPTS += --configure-flag --with-sysroot=/opt/x"
    echo "CONFIGUREOPTS += --configure-var libdirs=/opt/a:/opt/b"
    echo "CONFIGUREOPTS += --env BINDIRS=/opt/a"
} > $top/near-miss/Configfile
(cd $top/near-miss && $PTEST_BINARY $PCONFIGURE_ARGS)
test -f $top/near-miss/Makefile

##############################################################################
# A path make would expand is not a path this can check                      #
##############################################################################
# Everything checked_project_path() decides is decided lexically, of
# the text exactly as the Configfile wrote it -- which is what makes
# the answer the same read from the top and read from inside a
# subproject.  A make substitution reference has no slash in it, so it
# passes every one of those checks as a single harmless-looking
# component, and then the "$(abspath ...)" that the prefix goes into
# expands it to whatever the variable held.
#
# The one below comes out as "obj/../../elsewhere": lexically inside
# the object directory, actually a directory beside the project, and
# installed into by a plain "make".
refuses prefix-expansion '--prefix obj/$(CURDIR:%=..)/$(CURDIR:%=..)/gone'
grep -q "is a make expansion rather than a path" $top/prefix-expansion.out
grep -q "write it the way the project spells it" $top/prefix-expansion.out

# The same question about the other path a CONFIGUREOPTS writes, since
# one function answers it for both and a --depend that make expands is
# a prerequisite nothing here can resolve.
refuses depend-expansion '--depend $(CURDIR)/tools/thing'
grep -q "is a make expansion rather than a path" $top/depend-expansion.out

# And what still works, which is what says the refusal is about the
# expansion rather than about the option: a value that reaches the
# tree unread is where "$(abspath x)" goes on meaning what it says.
mkdir -p $top/expansion-ok/sub
cp $fakedir/configure.template $top/expansion-ok/sub/configure
chmod +x $top/expansion-ok/sub/configure
{
    echo "BUILD_SYSTEMS += autotools"
    echo ""
    echo "SUBPROJECTS   += sub"
    echo 'CONFIGUREOPTS += --configure-var CC=$(abspath tools/cc)'
    echo 'CONFIGUREOPTS += --env PATH=/opt/bin:$(PATH)'
} > $top/expansion-ok/Configfile
(cd $top/expansion-ok && $PTEST_BINARY $PCONFIGURE_ARGS)
test -f $top/expansion-ok/Makefile

##############################################################################
# A SUBPROJECT_TARGETS is a file the tree builds                             #
##############################################################################
# It is named relative to the directory the tree builds into, so a
# path that climbs out of there names something this tree didn't make
# -- and the rule it would get says the file is built by a sub-make
# that never touches it.
#
# The bare ".." is the one a check written as "starts with '../'" lets
# through, since there is no trailing slash on it to match, and it is
# the worst of them: "../out" names a directory beside the project and
# ".." names the directory the whole checkout is in.  An earlier round
# of this shipped that as an "rm -rf ..".
subproject_target_refuses()
{
    mkdir -p $top/$1/sub
    cp $fakedir/configure.template $top/$1/sub/configure
    chmod +x $top/$1/sub/configure

    {
        echo "BUILD_SYSTEMS += autotools"
        echo ""
        echo "SUBPROJECTS   += sub"
        echo "SUBPROJECT_TARGETS += $2"
    } > $top/$1/Configfile
    cat $top/$1/Configfile

    if (cd $top/$1 && $PTEST_BINARY $PCONFIGURE_ARGS) > $top/$1.out 2>&1
    then
        exit 1
    fi
    cat $top/$1.out
    test ! -e $top/$1/Makefile
}

subproject_target_refuses target-dotdot ".."
grep -q "'SUBPROJECT_TARGETS ..' reaches outside" $top/target-dotdot.out

subproject_target_refuses target-climb "../../elsewhere/tool"
grep -q "reaches outside" $top/target-climb.out

subproject_target_refuses target-absolute "/usr/local/bin/tool"
grep -q "is an absolute path" $top/target-absolute.out

subproject_target_refuses target-expansion '$(CURDIR)/tool'
grep -q "is a make expansion rather than a path" $top/target-expansion.out

##############################################################################
# An --env is a shell assignment or it is nothing                            #
##############################################################################
# The name in front of the '=' is the one piece of a CONFIGUREOPTS
# that reaches a recipe unquoted, and it has to be: quoted, it stops
# being a shell assignment and becomes the name of a program nobody
# has.  So what a shell reads as a name has to be asked out here,
# where the line that got it wrong can still be quoted back.  Left to
# the recipe, this is an Error 127 in the middle of a build, from a
# line that was read without a murmur.
refuses env-digit "--env 2FOO=bar"
grep -q "'--env 2FOO=bar' doesn't start with a variable name" \
    $top/env-digit.out
grep -q "the one part of this that can't be quoted" $top/env-digit.out
grep -q "write something like '--env PATH=/opt/gnubin:\$(PATH)'" \
    $top/env-digit.out

refuses env-space "--env RUST FLAGS=-O2"
grep -q "'--env RUST FLAGS=-O2' doesn't start with a variable name" \
    $top/env-space.out

refuses env-nameless "--env =-O2"
grep -q "'--env =-O2' doesn't start with a variable name" \
    $top/env-nameless.out

refuses env-value "--env RUSTFLAGS"
grep -q "'--env RUSTFLAGS' has no value" $top/env-value.out

# An autotools flag written where a pconfigure option goes.  It is an
# easy mistake because both of them start with two dashes, so the
# answer is the list of the ones that would have worked.
refuses bad-opt "--enable-foo"
grep -q "unknown CONFIGUREOPTS '--enable-foo'" $top/bad-opt.out
grep -q "'--configure-flag --enable-foo' passes one argument to ./configure" \
    $top/bad-opt.out
grep -q "'--prefix DIR' says where the tree installs to" $top/bad-opt.out

# And an option whose name merely starts with one of the real ones,
# which is what a reader that took whatever followed the name as the
# value would wave through.  "--targetx install" would arrive as a
# "--target" worth "install": a tree asked for a target nobody wrote
# down, configured and built with nothing said about it, and a
# Configfile line that does not mean what it says.  The character
# after the name has to be a space or an '=' before the rest of the
# word is a value at all, which is what turns this back into the
# typo it is.
refuses glued-opt "--targetx install"
grep -q "unknown CONFIGUREOPTS '--targetx install'" $top/glued-opt.out
grep -q "'--target NAME' asks the tree for a target" $top/glued-opt.out

exit 0
