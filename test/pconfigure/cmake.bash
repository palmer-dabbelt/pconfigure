#include "harness_start.bash"

top="$tempdir"

##############################################################################
# A cmake that isn't cmake                                                   #
##############################################################################
# What's under test here is the command line pconfigure writes and what
# happens to the files it names -- not what cmake does once it's been
# run, which is cmake's business and is tested rather thoroughly by
# the people who write it.  So cmake is a shell script on the PATH: it
# behaves identically on a machine with cmake 3.29 on it and on one
# with none, it can't change its mind about where it puts things
# between releases, and it leaves a log of how it was called, which is
# what turns "the Makefile says cmake -B obj/sub/build" into
# "obj/sub/build is where cmake was told to build".
#
# It lives beside the fixture rather than inside it: anything under
# "sub" is something pconfigure may chase as a dependency, and every
# "nothing was written inside the vendored tree" assertion below would
# have to reason about it.
mkdir -p $top/fake
export CMAKE_FAKE_LOG="$top/fake/ran.log"

cat >$top/fake/cmake <<'EOF'
#!/bin/sh
set -e

echo "cmake $*" >> "$CMAKE_FAKE_LOG"
echo "env MY_ENV=$MY_ENV" >> "$CMAKE_FAKE_LOG"

mode=configure
source=
build=
generator=
prefix=
libdir=lib
defines=
target=
parallel=

while [ "$#" -gt 0 ]
do
    case "$1" in
    --build)    mode=build; build="$2";     shift 2;;
    --target)   target="$2";                shift 2;;
    --parallel) parallel="$2";              shift 2;;
    -S)         source="$2";                shift 2;;
    -B)         build="$2";                 shift 2;;
    -G)         generator="$2";             shift 2;;
    -D*)
        defines="$defines
${1#-D}"
        case "$1" in
        -DCMAKE_INSTALL_PREFIX=*)
            prefix="${1#-DCMAKE_INSTALL_PREFIX=}"
            ;;
        # A relative DESTINATION is joined to CMAKE_INSTALL_PREFIX by
        # the install() that reads it, which is what makes a relative
        # one of these unable to leave the prefix -- and so the one
        # shape of this variable pconfigure takes.  The default is
        # what GNUInstallDirs would have given, so a project that says
        # nothing installs exactly where it did before.
        -DCMAKE_INSTALL_LIBDIR=*)
            libdir="${1#-DCMAKE_INSTALL_LIBDIR=}"
            ;;
        esac
        shift 1
        ;;
    *)                                      shift 1;;
    esac
done

# Being told where to build is the whole of how a cmake build stays
# out of the tree it is building, so a pconfigure that forgot to say
# it is a bug this is here to catch rather than something to work
# around.  Refusing is what makes "nothing was written inside sub" an
# assertion instead of a coincidence.
#
# This and the two refusals below are run on purpose once, just after
# the fake is written, because nothing else here ever reaches them.
if [ -z "$build" ]
then
    echo "cmake: run without -B" 1>&2
    exit 1
fi

if [ "$mode" = "build" ]
then
    # What the build was asked for, one line per run, left in the
    # build directory where the test can read it back.  The two values
    # go in brackets because the whole of what the quoting around a
    # target buys is whether it arrived as one argument or as several,
    # and a target logged bare looks the same either way.
    echo "build target=[$target] parallel=[$parallel]" \
        >> "$build/cmake-built.txt"
    exit 0
fi

if [ -z "$source" ]
then
    echo "cmake: run without -S" 1>&2
    exit 1
fi

if [ ! -f "$source/CMakeLists.txt" ]
then
    echo "cmake: '$source' has no CMakeLists.txt in it" 1>&2
    exit 1
fi

mkdir -p "$build"

# The cache is what cmake leaves behind to say it configured this
# directory, and it's what the rule pconfigure writes hangs off.  Every
# -D it was handed goes in it, which is how the test tells "the
# Makefile mentions the value" from "cmake was handed the value".
{
    echo "CMAKE_HOME_DIRECTORY:INTERNAL=$source"
    echo "CMAKE_GENERATOR:INTERNAL=$generator"
    echo "$defines" | sed '/^$/d'
} > "$build/CMakeCache.txt"

# And the build system it generates, which for the "Unix Makefiles"
# generator is a Makefile that a recursive $(MAKE) can run.  Every
# rule leaves a witness file behind, since a make recursing into a
# directory is invisible from outside otherwise, and "all" is first
# because a make handed no target at all runs whatever its Makefile
# mentions first.
{
    printf 'PREFIX = %s\n' "$prefix"
    printf 'LIBDIR = %s\n' "$libdir"
    printf '\n'
    printf 'all:\n'
    printf '\t@echo "all ran" > built.txt\n'
    printf '\t@echo "MY_VAR=$(MY_VAR)" >> built.txt\n'
    printf '\t@echo "MY_ENV=$$MY_ENV" >> built.txt\n'
    printf '\n'
    printf 'extra:\n'
    printf '\t@echo "extra ran" > extra.txt\n'
    printf '\n'
    printf 'more:\n'
    printf '\t@echo "more ran" > more.txt\n'
    printf '\n'
    # Three files rather than one, and only one of them is ever named
    # by a SUBPROJECT_TARGETS.  That is what tells "the prefix survived"
    # from "the one path the Makefile happens to name survived": a
    # cleaning target that reads the Makefile back to decide what is
    # still wanted keeps exactly the named one and takes the headers
    # and libraries beside it, which is a toolchain that looks present
    # and doesn't work.
    printf 'install:\n'
    printf '\t@mkdir -p $(PREFIX)/bin $(PREFIX)/$(LIBDIR) $(PREFIX)/include\n'
    printf '\t@echo "installed" > $(PREFIX)/bin/tool\n'
    printf '\t@echo "installed" > $(PREFIX)/$(LIBDIR)/libtool.a\n'
    printf '\t@echo "installed" > $(PREFIX)/include/tool.h\n'
} > "$build/Makefile"
EOF
chmod +x $top/fake/cmake

# Before the first pconfigure run rather than just before the first
# make: pconfigure is allowed to go looking for the programs a build
# system needs, and a fake that only existed later would be a
# different test than the one that runs in CI.
export PATH="$top/fake:$PATH"

# A tree that looks like a cmake project from outside, which is all
# anybody gets to look at: a CMakeLists.txt, some sources it would
# name, and a module directory of the kind cmake projects keep.
fake_tree()
{
    mkdir -p "$1/src" "$1/cmake"

    cat >"$1/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.13)
project(tool C)
add_executable(tool src/tool.c)
EOF

    cat >"$1/src/tool.c" <<'EOF'
int main(void) { return 0; }
EOF

    cat >"$1/cmake/helper.cmake" <<'EOF'
set(HELPER on)
EOF
}

fake_tree $top/sub
mkdir -p $top/src

# The fake's three refusals, run here rather than left to be believed.
# Each of them is a net under an assertion further down -- "nothing was
# written inside sub" rests on pconfigure passing -B, and "cmake was
# pointed at the tree" rests on -S naming a directory with a
# CMakeLists.txt in it -- and nothing pconfigure writes today is wrong
# in any of those ways, which is exactly the problem: a net with a typo
# in it catches nothing while looking precisely like one that works.
# So the only thing that ever takes one of these arms is this block,
# and it takes them on purpose.
#
# Through a log of their own, since these calls are not calls the
# Makefile made and the log the assertions below read is a record of
# what the Makefile did.
if CMAKE_FAKE_LOG=$top/fake/probe.log $top/fake/cmake -S $top/sub \
    > $top/fake/no-b.out 2>&1
then
    exit 1
fi
grep -q "cmake: run without -B" $top/fake/no-b.out

if CMAKE_FAKE_LOG=$top/fake/probe.log $top/fake/cmake -B $top/fake/scratch \
    > $top/fake/no-s.out 2>&1
then
    exit 1
fi
grep -q "cmake: run without -S" $top/fake/no-s.out

if CMAKE_FAKE_LOG=$top/fake/probe.log \
    $top/fake/cmake -S $top -B $top/fake/scratch \
    > $top/fake/no-lists.out 2>&1
then
    exit 1
fi
grep -q "has no CMakeLists.txt in it" $top/fake/no-lists.out

# And all three refused before writing anything, which is what makes
# "nothing was written inside sub" a claim about pconfigure rather than
# about how far the fake got.
test ! -e $top/fake/scratch

##############################################################################
# Configuring                                                                #
##############################################################################
# Nothing inside the vendored tree says a word about pconfigure:
# BUILD_SYSTEMS says cmake is available, and which subproject gets
# built that way is worked out from what's in the directory.
#
# The two awkward values are in here on purpose.  A cmake list is
# semicolon-separated and a semicolon in a make recipe ends the
# command; a flags variable has spaces in it and has to arrive as one
# argument rather than as three.  Both are what the quoting is for.
cat >$top/Configfile <<'EOF'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += sub
CONFIGUREOPTS += --build-type Release
CONFIGUREOPTS += --define CISCV_LIST=one;two
CONFIGUREOPTS += --define CISCV_FLAGS=-g -O2
CONFIGUREOPTS += --env MY_ENV=one two
MAKEOPS       += MY_VAR=first
SUBPROJECT_TARGETS += bin/tool

LANGUAGES     += c
BINARIES      += test
SOURCES       += test.c
EOF

cat >$top/src/test.c <<'EOF'
int main(void) { return 0; }
EOF

cd $top
$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# Nothing at all was written inside the vendored tree.  In particular
# no cache: an in-source cmake build is what "-S" and "-B" exist to
# avoid, and it's the thing that would leave somebody else's checkout
# full of our output.
test ! -e sub/CMakeCache.txt
test ! -e sub/Makefile
test ! -e sub/build
test ! -e sub/obj

# What configure time writes on this side of the fence is one of the
# two lists of options the tree is about to be built with: the
# configure-side one, which pconfigure writes after the Makefile and
# so can never end up describing a run that never finished writing
# one.  The build-side list is written by make instead, out of the
# recipe that reads it, so at this point there isn't one.  The build
# directory is still make's to create too.
test -f obj/sub/configure-opts
test ! -e obj/sub/build-opts
test ! -e obj/sub/build
test ! -e obj/sub/build-stamp

# The rules that drive it live in the Makefile of whoever pulled it
# in, since there's nowhere else for them to go.
grep -q "^obj/sub/build/CMakeCache.txt:" Makefile
grep -q "^obj/sub/build-stamp:" Makefile
grep -q "^all: obj/sub/build-stamp$" Makefile

# The configure rule waits for the options it configures with and for
# nothing else that changes: a reconfigure here throws the build
# directory away, so an edit to a CMakeLists.txt must not reach it.
# The build rule is where that edit lands instead.
grep -q "^obj/sub/build/CMakeCache.txt: obj/sub/configure-opts$" Makefile

grep "^obj/sub/build-stamp:" Makefile > stamp.dep
cat stamp.dep
grep -q "obj/sub/build/CMakeCache.txt" stamp.dep
grep -q "obj/sub/build-opts" stamp.dep
grep -q "wildcard" stamp.dep

# And the build-side options are a rule rather than a file pconfigure
# left lying about, hanging off a name that is never a file so that
# make asks it on every build.  That is the only way a file written
# out of a recipe stays in step with the recipe: written from where
# the rules are made, it can get ahead of the Makefile that guards it
# and then say what the next run was going to say without ever having
# been built that way.
grep -q "^\.PHONY: obj/sub/build-opts-force$" Makefile
grep -q "^obj/sub/build-opts: obj/sub/build-opts-force$" Makefile

awk '/^\t/ { if (p) print; next } { p = 0 } /^obj\/sub\/build-opts:/ { p = 1 }' Makefile > opts.rule
cat opts.rule

# The options go in as they were written: '$$' so make hands the shell
# what the Configfile said rather than what a variable happens to hold,
# and quoted so a cmake list arrives as one argument.
grep -q -- "'--env MY_ENV=one two'" opts.rule
grep -q -- "'MAKEOPS MY_VAR=first'" opts.rule

# And the file only moves when what it says moves, which is what keeps
# a build that is already done from being redone on every single make.
grep -q "cmp -s" opts.rule

grep "^obj/sub/build/CMakeCache.txt:" Makefile > config.dep
cat config.dep
if grep -q "wildcard" config.dep
then
    exit 1
fi

# The guess about what the tree could read is one word per directory,
# through a $(wildcard) that make re-expands rather than a list fixed
# when pconfigure looked.  A submodule bump deletes files, and a
# prerequisite that is named outright and has gone away stops make
# building anything at all.
grep -q -- "sub/[*]" stamp.dep
grep -q -- "sub/src/[*]" stamp.dep
grep -q -- "sub/cmake/[*]" stamp.dep

# The recipe, pulled out so that what is in it can be told from what
# is merely somewhere in the Makefile.
awk '/^\t/ { if (p) print; next } { p = 0 } /^obj\/sub\/build\/CMakeCache.txt:/ { p = 1 }' Makefile > config.rule
cat config.rule

# Configuring is starting over: the directory goes first, because a
# cmake cache keeps a -D that has been deleted from the Configfile and
# refuses a different generator outright.
grep -q "rm -fr obj/sub/build" config.rule

# And the install goes with it, since what a configuration installed
# does not stop existing when the line that asked for it is deleted --
# it goes on being found by anything that looks one "bin" up and goes
# on satisfying the "test -e" behind a SUBPROJECT_TARGETS.  Only this
# tree's own prefix: a --prefix names a directory peers install into.
grep -q "rm -fr obj/sub/prefix" config.rule
grep -q "cmake -S sub -B obj/sub/build" config.rule
grep -q -- "-G 'Unix Makefiles'" config.rule

# The install prefix reaches cmake absolutely, because cmake bakes one
# into its cache and into what it builds, and a relative one would
# mean whichever directory somebody was standing in.
grep -q -- "'-DCMAKE_INSTALL_PREFIX=\$(abspath obj/sub/prefix)'" config.rule

# One argument each, quotes and all, however many semicolons and
# spaces are in them.
grep -q -- "'-DCMAKE_BUILD_TYPE=Release'" config.rule
grep -q -- "'-DCISCV_LIST=one;two'" config.rule
grep -q -- "'-DCISCV_FLAGS=-g -O2'" config.rule

# The environment goes in front of the whole command, which is what
# makes it an environment variable rather than an argument -- and the
# value is quoted while the name is not, which is the only way round
# that works: a shell reads "NAME=VALUE cmd" as an assignment in front
# of a command, while 'NAME=VALUE' quoted whole is the name of a
# program nobody has.  Written without the quotes -- which is how this
# was first written -- the second word of the value stops being part
# of the assignment and becomes a command the shell runs once cmake
# has finished, so the recipe dies at build time having been accepted
# without a murmur at configure time.
grep -q "MY_ENV='one two' cmake -S sub" config.rule
if grep -q "MY_ENV=one two cmake" config.rule
then
    exit 1
fi

awk '/^\t/ { if (p) print; next } { p = 0 } /^obj\/sub\/build-stamp:/ { p = 1 }' Makefile > stamp.rule
cat stamp.rule

# The default generator is built by a recursive $(MAKE), which is the
# whole reason it's the default: that token is what hands this build
# the jobserver of the make that ran it, so a "make -j8" up here stays
# eight jobs in total.
grep -q "\$(MAKE) --no-print-directory -C obj/sub/build" stamp.rule

# A MAKEOPS is one argument however many spaces are in it, and it goes
# after the directory rather than in front of the command: a make
# command-line variable beats what the tree's own Makefile says and an
# environment variable doesn't.
grep -q -- "'MY_VAR=first'" stamp.rule

# Twice: once to build and once to install, in that order, because
# installing is part of building here -- a vendored tool is vendored so
# the rest of this build can run it, and the rest of this build
# happens during "make" rather than during "make install".
test "$(grep -c -- "--no-print-directory -C obj/sub/build" stamp.rule)" = "2"
grep -n -- "-C obj/sub/build 'MY_VAR=first'$" stamp.rule | cut -d: -f1 > build.at
grep -n -- "-C obj/sub/build 'MY_VAR=first' 'install'$" stamp.rule | cut -d: -f1 > install.at
cat build.at install.at
test "$(cat build.at)" -lt "$(cat install.at)"

# A SUBPROJECT_TARGETS is named from wherever the tree last wrote,
# which for a tree that installs is the prefix.
grep -q "^obj/sub/prefix/bin/tool: obj/sub/build-stamp$" Makefile
grep -q "^all: obj/sub/prefix/bin/tool$" Makefile

# The two files, exactly.  Which options land in which one is the
# whole of this build system's reconfigure story: a configure-side
# option costs a rebuild from scratch and a build-side one costs one
# more run of a build that has already been done, so they can't share
# a file.  An --env is in both because both programs run in it.
cat >expected-configure-opts <<'EOF'
--build-type Release
--define CISCV_LIST=one;two
--define CISCV_FLAGS=-g -O2
--env MY_ENV=one two
EOF
diff expected-configure-opts obj/sub/configure-opts

cat >expected-build-opts <<'EOF'
--env MY_ENV=one two
MAKEOPS MY_VAR=first
EOF

##############################################################################
# Building                                                                   #
##############################################################################
tab="$(printf '\t')"

make $MAKE_ARGS > first.out
cat first.out
grep -q "CMAKE${tab}sub" first.out
grep -q "BUILD${tab}sub" first.out

# cmake was run the way the Makefile said it would be, which is a
# different claim than the Makefile saying it.
cat $CMAKE_FAKE_LOG
grep -q -- "-S sub -B obj/sub/build" $CMAKE_FAKE_LOG
grep -q "env MY_ENV=one two" $CMAKE_FAKE_LOG

# And it was handed the values, rather than them merely appearing
# somewhere in a recipe.  Both ends anchored: a semicolon that ended
# the command early would leave "one" here and "two" as a program
# nobody has.
cat obj/sub/build/CMakeCache.txt
grep -q "^CISCV_LIST=one;two$" obj/sub/build/CMakeCache.txt
grep -q "^CISCV_FLAGS=-g -O2$" obj/sub/build/CMakeCache.txt
grep -q "^CMAKE_BUILD_TYPE=Release$" obj/sub/build/CMakeCache.txt
grep -q "^CMAKE_GENERATOR:INTERNAL=Unix Makefiles$" obj/sub/build/CMakeCache.txt

# The generated build system ran, and it ran with both kinds of
# variable: asking the tree for them is the only way to tell an
# environment variable from a make command-line one, since a Makefile
# that only ever read one of them would be happy either way.
cat obj/sub/build/built.txt
grep -q "^all ran$" obj/sub/build/built.txt
grep -q "^MY_VAR=first$" obj/sub/build/built.txt
grep -q "^MY_ENV=one two$" obj/sub/build/built.txt

# The install ran too, which is what the SUBPROJECT_TARGETS above was
# naming.  All of it: the two files nothing names are what later says
# whether a cleaning target kept the prefix or kept the one path the
# Makefile happens to mention.
test -f obj/sub/build-stamp
test "$(cat obj/sub/prefix/bin/tool)" = "installed"
test -f obj/sub/prefix/lib/libtool.a
test -f obj/sub/prefix/include/tool.h

# And the build-side options, which this make wrote out of the recipe
# that reads them rather than pconfigure out of the Configfile.
diff expected-build-opts obj/sub/build-opts

# The project's own code built too, which is the other half of what a
# vendored tree is for: something in this build is going to use it.
test -f bin/test

# And still nothing inside the tree.
test ! -e sub/CMakeCache.txt
test ! -e sub/build
test ! -e sub/obj

# A second make in a tree that's already built doesn't recurse at all,
# which is the whole point of chasing those directories.
#
# The build-opts rule is the one thing here that does run: it hangs off
# a name that is never a file, so make asks it every single time, which
# is what keeps the file it writes from ever getting out of step with
# the recipe that reads it.  What that costs is a mkdir, a printf and a
# cmp per vendored tree per make, and the whole of what makes that the
# right price is that it is all it costs -- so the file it leaves
# behind has to come out of this identical, down to the mtime that is
# the only thing anything downstream reads, and the temporary it writes
# through has to be gone.  A rule that quietly moved either of those
# would rebuild the vendored tree on every make, which would not look
# like a cost at all until somebody vendored LLVM.
cp obj/sub/build-opts before-second
touch before-second-make
sleep 2s

make $MAKE_ARGS > second.out
cat second.out
if grep -q "CMAKE" second.out
then
    exit 1
fi
if grep -q "BUILD" second.out
then
    exit 1
fi

diff before-second obj/sub/build-opts
find obj/sub/build-opts -newer before-second-make > second-moved.txt
cat second-moved.txt
test ! -s second-moved.txt
test ! -e obj/sub/build-opts.tmp

##############################################################################
# What a rebuild costs                                                       #
##############################################################################
# A file left in the build directory by hand, which is how the test
# tells "cmake was run again" from "the build directory was thrown
# away and made again".  The two are the same thing here and are not
# the same thing anywhere else, so it's worth saying which one
# happened.
touch obj/sub/build/marker

# Touching a source gets us back into the tree and no further: the
# generated build system decides what to recompile, which is a job it
# is far better at than any guess made out here.
sleep 2s
touch sub/src/tool.c
make $MAKE_ARGS > third.out
cat third.out
grep -q "BUILD${tab}sub" third.out
if grep -q "CMAKE" third.out
then
    exit 1
fi
test -f obj/sub/build/marker

# A build-side option is one more run of a build that has already
# happened.  The tree is asked for "extra" instead of for its default,
# and the build directory is left exactly where it was -- which is the
# reason these options are written into a file of their own rather
# than into the one the configure hangs off.
sleep 2s
cat >$top/Configfile <<'EOF'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += sub
CONFIGUREOPTS += --build-type Release
CONFIGUREOPTS += --define CISCV_LIST=one;two
CONFIGUREOPTS += --define CISCV_FLAGS=-g -O2
CONFIGUREOPTS += --env MY_ENV=one two
MAKEOPS       += MY_VAR=first
SUBPROJECT_TARGETS += bin/tool
CONFIGUREOPTS += --target extra

LANGUAGES     += c
BINARIES      += test
SOURCES       += test.c
EOF
$PTEST_BINARY $PCONFIGURE_ARGS

# One argument, quoted, like everything else a CONFIGUREOPTS wrote:
# --target says one target and means it, so what is in one of them is
# the name rather than a list this gets to split on the spaces.
awk '/^\t/ { if (p) print; next } { p = 0 } /^obj\/sub\/build-stamp:/ { p = 1 }' \
    Makefile > fourth-stamp.rule
cat fourth-stamp.rule
grep -q -- "-C obj/sub/build 'MY_VAR=first' 'extra'$" fourth-stamp.rule

make $MAKE_ARGS > fourth.out
cat fourth.out
grep -q "BUILD${tab}sub" fourth.out
if grep -q "CMAKE" fourth.out
then
    exit 1
fi
test -f obj/sub/build/extra.txt
test -f obj/sub/build/marker

# A configure-side option is a build directory thrown away and made
# again, because a cmake cache keeps a -D that has gone away and there
# is no such thing as telling it to forget one.  The marker is how
# that gets said out loud.
#
# The stale tool stands in for what a configuration that is about to be
# deleted installed.  Starting over that left the prefix alone would
# leave it on the path of anything that looks one "bin" up, and leave
# it satisfying the "test -e" a SUBPROJECT_TARGETS gets -- a build that
# reports success while shipping a tool it no longer builds.
mkdir -p obj/sub/prefix/bin
echo stale > obj/sub/prefix/bin/stale-tool
sleep 2s
cat >$top/Configfile <<'EOF'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += sub
CONFIGUREOPTS += --build-type Release
CONFIGUREOPTS += --define CISCV_LIST=one;two
CONFIGUREOPTS += --define CISCV_FLAGS=-g -O2
CONFIGUREOPTS += --env MY_ENV=one two
MAKEOPS       += MY_VAR=first
SUBPROJECT_TARGETS += bin/tool
CONFIGUREOPTS += --target extra
CONFIGUREOPTS += --define CISCV_EXTRA=yes

LANGUAGES     += c
BINARIES      += test
SOURCES       += test.c
EOF
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS > fifth.out
cat fifth.out
grep -q "CMAKE${tab}sub" fifth.out
grep -q "BUILD${tab}sub" fifth.out
grep -q "^CISCV_EXTRA=yes$" obj/sub/build/CMakeCache.txt
test ! -e obj/sub/build/marker
test ! -e obj/sub/prefix/bin/stale-tool

# And everything the current configuration does install is back, since
# the stamp the install hangs off waits on the rule that threw the
# prefix away.
test "$(cat obj/sub/prefix/bin/tool)" = "installed"
test -f obj/sub/prefix/include/tool.h

# Running pconfigure again without changing anything doesn't rewrite
# either file, which is what keeps a configure from being a reason to
# rebuild.  The sleep is what keeps this from being a statement about
# the filesystem's clock instead: a second write inside the same mtime
# tick looks identical to no write at all.
touch before-noop
sleep 2s
$PTEST_BINARY $PCONFIGURE_ARGS
find obj/sub/configure-opts obj/sub/build-opts -newer before-noop > rewritten.txt
cat rewritten.txt
test ! -s rewritten.txt

make $MAKE_ARGS > sixth.out
cat sixth.out
if grep -q "CMAKE" sixth.out
then
    exit 1
fi
if grep -q "BUILD" sixth.out
then
    exit 1
fi

##############################################################################
# A configure that gave up half way                                          #
##############################################################################
# A build system writes its rules long before pconfigure writes the
# Makefile, so anything it writes from there can end up describing a
# run that never produced a Makefile -- and a file that already says
# what the next run was going to say is a file the next run leaves
# alone.  What that costs is a tree that stays built the way it was,
# with a Makefile that says otherwise and nothing anywhere to say so.
#
# The mistake is deliberately somewhere else in the Configfile: what
# is under test is the ordering, not the mistake.
cp obj/sub/build-opts before-abort
cp Makefile before-abort-makefile
cat >$top/src/broken.unknown <<'EOF'
nothing knows how to build this
EOF

sleep 2s
cat >$top/Configfile <<'EOF'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += sub
CONFIGUREOPTS += --build-type Release
CONFIGUREOPTS += --define CISCV_LIST=one;two
CONFIGUREOPTS += --define CISCV_FLAGS=-g -O2
CONFIGUREOPTS += --env MY_ENV=one two
MAKEOPS       += MY_VAR=first
SUBPROJECT_TARGETS += bin/tool
CONFIGUREOPTS += --target extra
CONFIGUREOPTS += --define CISCV_EXTRA=yes
CONFIGUREOPTS += --target more

LANGUAGES     += c
BINARIES      += test
SOURCES       += test.c

BINARIES      += broken
SOURCES       += broken.unknown
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS > aborted.out 2>&1
then
    exit 1
fi
cat aborted.out

# The run gave up before it wrote a Makefile, which is the whole shape
# of the problem: whatever it had already written is now describing a
# build that nothing is going to do.  So it must not have written
# anything -- the build-side options still say what the Makefile on
# disk says, which is the only thing keeping the two of them talking
# about the same build.
diff before-abort-makefile Makefile
diff before-abort obj/sub/build-opts

# And a make in between, which is the step that turns a file that got
# ahead into a tree that is wrong: it builds with the recipe that is
# actually on disk and stamps the result newer than the options it was
# not built with.
sleep 2s
make $MAKE_ARGS > aborted-make.out 2>&1
cat aborted-make.out
test ! -e obj/sub/build/more.txt

# And now the unrelated mistake is fixed.  The target that was asked
# for two runs ago has still never been built, so this is the make
# that has to build it.
sleep 2s
cat >$top/Configfile <<'EOF'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += sub
CONFIGUREOPTS += --build-type Release
CONFIGUREOPTS += --define CISCV_LIST=one;two
CONFIGUREOPTS += --define CISCV_FLAGS=-g -O2
CONFIGUREOPTS += --env MY_ENV=one two
MAKEOPS       += MY_VAR=first
SUBPROJECT_TARGETS += bin/tool
CONFIGUREOPTS += --target extra
CONFIGUREOPTS += --define CISCV_EXTRA=yes
CONFIGUREOPTS += --target more

LANGUAGES     += c
BINARIES      += test
SOURCES       += test.c
EOF
rm $top/src/broken.unknown

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS > recovered.out
cat recovered.out
grep -q "BUILD${tab}sub" recovered.out
test -f obj/sub/build/more.txt
grep -q -- "^--target more$" obj/sub/build-opts

# None of that was a reconfigure: no configure-side option moved, so
# the build directory is the one that was already there and the whole
# cost of the mistake was one more run of a build that had already
# happened.
if grep -q "CMAKE" recovered.out
then
    exit 1
fi

##############################################################################
# Cleaning                                                                   #
##############################################################################
# A vendored build lands in this project's object directory, where
# cache-clean would otherwise read the Makefile back, find that it
# says nothing about any of it, and throw away a build that's
# perfectly good.
make $MAKE_ARGS cache-clean
test -f obj/sub/build/CMakeCache.txt

# And the install, all of it.  cache-clean keeps what the Makefile
# says it builds, which, of an installed tree, is only whatever a
# SUBPROJECT_TARGETS named outright -- so a prefix it walked would come
# back with "bin/tool" and without the header and the library beside
# it, behind a build stamp that still says the tree is built, so no
# later make puts any of it back.  What keeps it whole is that the
# default prefix lives inside the one directory cache-clean is told to
# leave alone.
test -f obj/sub/prefix/bin/tool
test -f obj/sub/prefix/lib/libtool.a
test -f obj/sub/prefix/include/tool.h
test -f obj/sub/build-opts

# And it is told about that directory once rather than twice: the
# prefix is inside the tree's own output directory, which is already
# spared, so a second clause for it would say a thing that was already
# said and make a command nobody can read any longer.  The positive
# half is right above -- the files survived -- so this can only fail
# by saying too much.
grep -q -- "-not -path 'obj/sub/[*]'" Makefile
if grep -q -- "-not -path 'obj/sub/prefix/[*]'" Makefile
then
    exit 1
fi

make $MAKE_ARGS > seventh.out
cat seventh.out
if grep -q "BUILD" seventh.out
then
    exit 1
fi

# "make clean" takes the stamp and the install, and not the build
# directory: throwing that away would be an hour of LLVM to get back
# something this Makefile never had an opinion about, so what a clean
# does here is make the next make re-enter the tree and let the tree
# decide.
grep -q "clean-obj/sub/build-stamp:; @rm -fr obj/sub/build-stamp obj/sub/prefix$" Makefile

# Which is a claim about the whole of what a clean does rather than
# about the one rule that does the removing.  Two rules in this
# Makefile put that directory back -- the configure, which throws the
# build directory away and makes it again, and the build, which
# installs into the prefix -- and the options the second of them waits
# on hang off a name that is never a file, so make asks for them on
# every single make.  What keeps "the prefix is gone afterwards" true
# is not the "rm" above but that none of those is reachable from
# "clean": a clean that had picked one of them up somewhere among its
# prerequisites would, under "-j", run it beside the removal and leave
# whichever finished last.  So the whole of a clean has to be
# removals, which is a thing to look at rather than to reason about.
make $MAKE_ARGS -n clean > clean.dry
cat clean.dry
grep -q "^rm -fr obj/sub/build-stamp obj/sub/prefix$" clean.dry

# Said by taking the removals out and looking at what is left over,
# rather than by asking a grep for the lines that are not removals:
# "grep -q -v" does not mean the same thing to every grep that turns
# up as /usr/bin/grep, and one of the ones it does not mean is "there
# was a line that did not match".  An assertion that quietly agrees
# with itself on somebody else's machine is worse than no assertion,
# and the left-over lines are what anybody would want to read anyway.
sed '/^rm -fr /d' clean.dry > clean.not-a-removal
cat clean.not-a-removal
test ! -s clean.not-a-removal

make $MAKE_ARGS clean
test ! -e obj/sub/build-stamp
test -f obj/sub/build/CMakeCache.txt

# The install goes with the stamp, which costs a clean nothing it
# wasn't already costing: the stamp is what the install hangs off, so
# the next make re-enters the tree and installs again either way.
# What it buys is that a file a configuration stopped installing has a
# way out that isn't "go and read the build system's source".
test ! -e obj/sub/prefix

make $MAKE_ARGS > eighth.out
cat eighth.out
grep -q "BUILD${tab}sub" eighth.out
if grep -q "CMAKE" eighth.out
then
    exit 1
fi

test "$(cat obj/sub/prefix/bin/tool)" = "installed"
test -f obj/sub/prefix/include/tool.h

##############################################################################
# A chased path that went away                                               #
##############################################################################
# What went into the Makefile is one glob per directory rather than the
# list of files that happened to be in them when pconfigure looked, and
# a vendored tree is exactly the sort of thing that gets bumped to a
# version with different files in it.  Named outright, one of them
# disappearing stops make from building anything at all -- not just this
# subproject -- with an error whose way out it does not mention.
sleep 1
rm -r sub/cmake

make $MAKE_ARGS > gone.out 2>&1
cat gone.out

# make check still works in a project that vendors something, even
# though the vendored tree has no tests pconfigure knows how to run.
make $MAKE_ARGS check

# Undoing a configure throws away what the vendored build system
# produced, and leaves the vendored tree exactly as it was.
make $MAKE_ARGS distclean
test ! -e obj/sub
test ! -e sub/obj
test ! -e sub/CMakeCache.txt
test -f sub/CMakeLists.txt
test -f sub/src/tool.c

##############################################################################
# A generator that isn't make                                                #
##############################################################################
# Ninja is the other half of this build system and it changes the
# shape of the rules rather than a word in them: there is no sub-make,
# so there is nothing for a MAKEOPS to go on the command line of and
# nothing to take a parallelism from -- which is what --jobs is for.
#
# Only configured here, because this project is the one carrying every
# option at once and running a build of it would say nothing the rules
# below don't.  The section after this one is the one that runs a
# "cmake --build" for real.
mkdir -p $top/nin
fake_tree $top/nin/sub
fake_tree $top/nin/dep

cat >$top/nin/Configfile <<'EOF'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += sub
CONFIGUREOPTS += --generator Ninja
CONFIGUREOPTS += --jobs 4
CONFIGUREOPTS += --prefix obj/shared
CONFIGUREOPTS += --no-install
CONFIGUREOPTS += --target tool
CONFIGUREOPTS += --configure-arg -Wno-dev
CONFIGUREOPTS += --depend dep
SUBPROJECT_TARGETS += bin/tool

SUBPROJECTS   += dep
EOF

cd $top/nin
$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

awk '/^\t/ { if (p) print; next } { p = 0 } /^obj\/sub\/build\/CMakeCache.txt:/ { p = 1 }' Makefile > nin-config.rule
awk '/^\t/ { if (p) print; next } { p = 0 } /^obj\/sub\/build-stamp:/ { p = 1 }' Makefile > nin-stamp.rule
cat nin-config.rule nin-stamp.rule

grep -q -- "-G 'Ninja'" nin-config.rule

# Nothing is said about the build type unless somebody says it: what a
# tree defaults to is the tree's business.  The main project's rule
# above is where the same pattern was seen to match something real.
if grep -q "CMAKE_BUILD_TYPE" nin-config.rule
then
    exit 1
fi

# A --prefix is named relative to the project that asked for it, the
# same way a SUBPROJECTS is, and still reaches cmake absolutely.
grep -q -- "'-DCMAKE_INSTALL_PREFIX=\$(abspath obj/shared)'" nin-config.rule

# And it is the one thing configuring doesn't start over.  The whole
# reason anybody writes a --prefix is that several trees install into
# one directory, and this tree removing it would take a peer's install
# away from a peer whose stamp still says it is built -- so nothing
# would ever put it back.  The build directory still goes, which is
# what says this is a decision rather than a rule that was forgotten.
grep -q "rm -fr obj/sub/build" nin-config.rule
if grep -q "rm -fr obj/shared" nin-config.rule
then
    exit 1
fi

# A "make clean" doesn't take it either, and for the same reason with
# one more on top: "rm -fr" on a directory somebody wrote down by hand
# is not a promise a clean gets to make.
if grep -q "clean-obj/sub/build-stamp:.*obj/shared" Makefile
then
    exit 1
fi

# A --configure-arg is written the way it will appear, unquoted, since
# that is the only way to spell an option that is two words.
grep -q -- " -Wno-dev" nin-config.rule

# The build is cmake's own, which is the only thing that works without
# knowing what got generated, and it's told how many jobs to run
# because nothing else is going to tell it.
grep -q "cmake --build obj/sub/build --target 'tool' --parallel 4" nin-stamp.rule

# Once, not twice: --no-install means the install target isn't asked
# for.  The count is the assertion -- a missing install would otherwise
# look exactly like an install that was never grepped for.
test "$(grep -c -- "cmake --build obj/sub/build" nin-stamp.rule)" = "1"

# And no sub-make anywhere near it.  The pattern is the one the main
# project's stamp rule matched above, so a typo in it would have been
# caught there.
if grep -q -- "--no-print-directory -C obj/sub/build" nin-stamp.rule
then
    exit 1
fi

# A tree that doesn't install has only its build directory to offer,
# so that's what a SUBPROJECT_TARGETS is named from.
grep -q "^obj/sub/build/bin/tool: obj/sub/build-stamp$" Makefile

# And it has no install prefix for cache-clean to be told about, which
# is not the same as having one nobody uses.  The --prefix above is
# still written down and still reaches cmake; what it does not do is
# name a directory to spare, because nothing is ever installed into
# it and a spared directory that is never made is a cache-clean that
# reclaims slightly less than it could have.
if grep -q -- "-not -path 'obj/shared/[*]'" Makefile
then
    exit 1
fi

# And "no prefix at all" reaches that list as an empty string, which
# spelled into the command becomes the filesystem root: a cache-clean
# told to leave "/*" alone leaves everything alone.  Neither of these
# costs a build anything, which is exactly why they go unnoticed
# unless they are asked about outright.
if grep -q -- "-not -path '/[*]'" Makefile
then
    exit 1
fi

# A --depend on another vendored tree waits for that tree to have been
# built rather than for its directory to change, and the configure
# waits for it as well as the build: cmake runs the compiler while it
# is deciding what the tree can do.
grep -q "^obj/sub/build/CMakeCache.txt:.* obj/dep/build-stamp" Makefile
grep -q "^obj/sub/build-stamp:.* obj/dep/build-stamp" Makefile

# The second tree got the defaults, since the options above landed on
# the subproject that was open rather than on the build system.
grep -q "\$(MAKE) --no-print-directory -C obj/dep/build" Makefile

##############################################################################
# A generator that runs its own build                                        #
##############################################################################
# Everything above builds through the sub-make, so the other half of
# build_command() -- the "cmake --build" that works without knowing
# what got generated -- has only ever been read out of a Makefile.
# Which means the fake's whole build mode has never run either, and a
# fake that is never run is a fake that is allowed to be wrong.
#
# No fake ninja is needed for this: "cmake --build" is a call into
# cmake, and the cmake here is ours.
#
# The target is the awkward one on purpose.  A --target is one target,
# which is what makes the spaces and the semicolon in this one
# characters of its name rather than a list this may split -- and a
# semicolon pasted raw into a recipe ends the command, so the half
# after it would be handed to the shell as a program nobody has.  That
# is a Configfile accepted without a murmur at configure time and a
# build that dies at build time, which is the failure this whole file
# quotes against.
mkdir -p $top/nin-build
fake_tree $top/nin-build/sub

cat >$top/nin-build/Configfile <<'EOF'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += sub
CONFIGUREOPTS += --generator Ninja
CONFIGUREOPTS += --jobs 4
CONFIGUREOPTS += --no-install
CONFIGUREOPTS += --target one;two three
SUBPROJECT_TARGETS += cmake-built.txt
EOF

cd $top/nin-build
$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

awk '/^\t/ { if (p) print; next } { p = 0 } /^obj\/sub\/build-stamp:/ { p = 1 }' \
    Makefile > nb-stamp.rule
cat nb-stamp.rule
grep -q -- \
    "cmake --build obj/sub/build --target 'one;two three' --parallel 4" \
    nb-stamp.rule

make $MAKE_ARGS > nin-build.out
cat nin-build.out

# Which the fake wrote down as it was handed it, brackets and all.  The
# whole file rather than a grep: --no-install means exactly one build,
# so a second line would be an install asked for by a tree that said
# not to.
cat obj/sub/build/cmake-built.txt
test "$(cat obj/sub/build/cmake-built.txt)" = \
    "build target=[one;two three] parallel=[4]"

# And the tree is built, with its SUBPROJECT_TARGETS named from the
# build directory, since a tree that doesn't install has nowhere else
# to have put it.
test -f obj/sub/build-stamp
test -f obj/sub/build/cmake-built.txt
grep -q "^obj/sub/build/cmake-built.txt: obj/sub/build-stamp$" Makefile

##############################################################################
# A tree that doesn't install                                                #
##############################################################################
# --no-install with nothing else said, which is the combination that
# has a default prefix and no install to put in it.  The Ninja project
# above says --no-install too, but it says --prefix beside it, so
# everything below would have been true there for the other reason.
mkdir -p $top/no-install
fake_tree $top/no-install/sub

cat >$top/no-install/Configfile <<'EOF'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += sub
CONFIGUREOPTS += --no-install
SUBPROJECT_TARGETS += built.txt
EOF

cd $top/no-install
$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

awk '/^\t/ { if (p) print; next } { p = 0 } /^obj\/sub\/build\/CMakeCache.txt:/ { p = 1 }' \
    Makefile > no-install-config.rule
cat no-install-config.rule

# cmake is still told where an install would go: a prefix is baked into
# the cache and into what the tree builds, and a tree this build system
# doesn't install is still a tree somebody may install by hand.
grep -q -- "'-DCMAKE_INSTALL_PREFIX=\$(abspath obj/sub/prefix)'" \
    no-install-config.rule

# But nothing removes that directory, because nothing creates it.
# Starting over throws away what the old configuration produced, and
# what a tree that doesn't install produces is all in the build
# directory -- so an "rm -fr" on the prefix would be this recipe saying
# the build installs somewhere when it doesn't.  The build directory is
# still thrown away, which is what says this is a decision rather than
# a guard that was dropped.
grep -q "rm -fr obj/sub/build$" no-install-config.rule
if grep -q "rm -fr obj/sub/prefix" no-install-config.rule
then
    exit 1
fi

# And "make clean" takes the stamp and nothing else, for the same
# reason.  Anchored on the end of the line rather than grepped for the
# prefix's absence, so that a clean which grew a third path to remove
# has to be looked at rather than passing quietly.
grep -q "clean-obj/sub/build-stamp:; @rm -fr obj/sub/build-stamp$" Makefile

# Which is a claim about the build as well as about the Makefile: the
# directory both of those rules used to name is one a full build never
# brings into existence.
make $MAKE_ARGS > no-install.out
cat no-install.out
test -f obj/sub/build-stamp
test -f obj/sub/build/built.txt
test ! -e obj/sub/prefix

# A SUBPROJECT_TARGETS is named from the build directory here, since
# that is the tree's last word about what it produced.
grep -q "^obj/sub/build/built.txt: obj/sub/build-stamp$" Makefile

##############################################################################
# A prefix two trees share                                                   #
##############################################################################
# The only reason to write a --prefix at all is that one directory is
# meant to hold what more than one tree installed: a toolchain is a
# compiler out of one tree and a runtime out of another, and what
# makes it a toolchain rather than two build directories is that both
# of them landed in the same place.
#
# That is what the two "rm -fr"s naming an install prefix are
# conditional on, and this is the project that asks about it.  Both of
# them are right as long as the prefix is the one this build system
# invented inside the tree's own object directory: it holds what this
# tree installed and nothing else, and the next make puts it back.
# Pointed at a directory somebody wrote down, the configure rule and
# "make clean" each take a peer's install away from a peer whose stamp
# still says it is built, so nothing ever puts that back -- what goes
# wrong first is a link against a library that was there yesterday.
#
# The Ninja project above carries a --prefix too, but it says
# --no-install beside it, so both recipes are already silent there for
# the other reason: it would go on passing with the question about
# whose directory this is left unasked.
mkdir -p $top/shared-prefix
fake_tree $top/shared-prefix/one
fake_tree $top/shared-prefix/two

cat >$top/shared-prefix/Configfile <<'EOF'
BUILD_SYSTEMS += cmake
CONFIGUREOPTS += --prefix obj/shared

SUBPROJECTS   += one
SUBPROJECTS   += two
EOF

cd $top/shared-prefix
$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

awk '/^\t/ { if (p) print; next } { p = 0 } /^obj\/one\/build\/CMakeCache.txt:/ { p = 1 }' \
    Makefile > one-config.rule
awk '/^\t/ { if (p) print; next } { p = 0 } /^obj\/two\/build\/CMakeCache.txt:/ { p = 1 }' \
    Makefile > two-config.rule
cat one-config.rule two-config.rule

# Both trees were told the one prefix, which is what makes this a
# directory they share rather than two trees that merely each have
# one.  Asserted before anything about what the recipes don't say,
# since a CONFIGUREOPTS under a BUILD_SYSTEMS that reached only one of
# them would make every absence below true for a reason nobody meant.
grep -q -- "'-DCMAKE_INSTALL_PREFIX=\$(abspath obj/shared)'" one-config.rule
grep -q -- "'-DCMAKE_INSTALL_PREFIX=\$(abspath obj/shared)'" two-config.rule

# Starting over throws away the build directory, which is this tree's
# own, and stops there.  The removals are pulled out and matched whole
# rather than grepped for the prefix's absence, because the prefix is
# in both of these recipes already -- it is the -D that says where the
# tree installs -- so "does this rule mention obj/shared" is the wrong
# question and "what does this rule remove" is the one that can be
# answered.  Matching whole is also what keeps a recipe that stopped
# removing anything at all from passing by saying nothing.
grep "rm " one-config.rule > one.removals
grep "rm " two-config.rule > two.removals
cat one.removals two.removals
test "$(cat one.removals)" = "$(printf '\t@rm -fr obj/one/build')"
test "$(cat two.removals)" = "$(printf '\t@rm -fr obj/two/build')"

# A "make clean" doesn't take it either, and for the same reason with
# one more on top: "rm -fr" on a directory somebody wrote down by hand
# is not a promise a clean gets to make.  Anchored on the end of the
# line, so that a clean which grew a second path to remove has to be
# looked at rather than passing quietly.
grep -q "clean-obj/one/build-stamp:; @rm -fr obj/one/build-stamp$" Makefile
grep -q "clean-obj/two/build-stamp:; @rm -fr obj/two/build-stamp$" Makefile

# Which is so far a claim about the characters in a Makefile, and the
# thing worth having is the claim about what a build does with them.
# Both trees install now, into the one directory.
make $MAKE_ARGS > shared-first.out
cat shared-first.out
test -f obj/shared/bin/tool
test -f obj/shared/lib/libtool.a
test -f obj/shared/include/tool.h

# And a file put there by hand stands in for what a peer installed
# that neither of these trees ever writes.  It has to be a file
# nothing here installs: the two fixtures install the same three
# paths, so an install that was thrown away and put back by the tree
# that threw it away looks exactly like an install that was left
# alone.
echo "peer" > obj/shared/bin/peer-tool

# A clean takes both stamps and leaves the directory they installed
# into alone, all of it.  The next make re-enters both trees and
# installs again, and what nobody in this configuration installed is
# nobody here's to remove.
make $MAKE_ARGS clean
test ! -e obj/one/build-stamp
test ! -e obj/two/build-stamp
test "$(cat obj/shared/bin/peer-tool)" = "peer"
test -f obj/shared/bin/tool

make $MAKE_ARGS > shared-second.out
cat shared-second.out

# And a configure-side option on one of the two trees reconfigures
# that tree and leaves what the other one installed where it is.  This
# is the half with no way back: the peer is not rebuilt, because its
# stamp is exactly as new as it was and nothing it waits on has moved,
# so a configure that emptied the prefix here would leave the peer's
# files gone until somebody worked out that the tree to clean was the
# one whose options nobody had touched.
sleep 2s
cat >$top/shared-prefix/Configfile <<'EOF'
BUILD_SYSTEMS += cmake
CONFIGUREOPTS += --prefix obj/shared

SUBPROJECTS   += one
CONFIGUREOPTS += --define CISCV_EXTRA=yes

SUBPROJECTS   += two
EOF
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS > shared-third.out
cat shared-third.out
grep -q "CMAKE${tab}one" shared-third.out
if grep -q "CMAKE${tab}two" shared-third.out
then
    exit 1
fi
test "$(cat obj/shared/bin/peer-tool)" = "peer"

##############################################################################
# A vendored tree inside a subproject                                        #
##############################################################################
# A subproject's Makefile is written to be included by its parent's and
# to work on its own, so every path in it is spelled through a variable
# that is the subproject's directory from above and nothing from
# inside.  Every recipe line gets that treatment, which is right for
# the paths in a command and wrong for the one recipe here whose
# argument is not a path: build-opts is a list of options being written
# down, and text that means two different things depending on where
# make was run is text the reconfigure detection cannot use.
#
# The option below is the option as written in the subproject's own
# Configfile.  What makes it the awkward one is that it has the
# subproject's own directory name in it -- which is a thing people
# write, and which nothing about it being inside a printf argument
# would have stopped from being rewritten.
mkdir -p $top/nested/child
fake_tree $top/nested/child/vend

cat >$top/nested/Configfile <<'EOF'
SUBPROJECTS += child
EOF

cat >$top/nested/child/Configfile <<'EOF'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += vend
CONFIGUREOPTS += --env FOO=child/x
CONFIGUREOPTS += --env BAR=$(notdir one/two)
CONFIGUREOPTS += --target more
EOF

cd $top/nested
$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile child/obj/Makefile.child

# The subproject really is included rather than recursed into, which is
# what puts the variable in front of every path in the rules below --
# without it there would be nothing here to get wrong.
grep -q "^include \$(pconfigure_subdir_child)obj/Makefile.child$" Makefile

awk '/^\t/ { if (p) print; next } { p = 0 } /build-opts:/ { p = 1 }' \
    child/obj/Makefile.child > nested-opts.rule
cat nested-opts.rule

# The line that writes the options has no make variable in it at all.
# That is the whole assertion: a variable there is a recipe whose
# output depends on where make was run, and the only variable that
# could appear is the one standing in for the subproject's directory.
grep -- "printf" nested-opts.rule > nested-printf
cat nested-printf
if grep -q "pconfigure_subdir" nested-printf
then
    exit 1
fi

# The second '--env' is the other way a recipe gets rewritten before
# anything reads it, and the one that survives being written into a
# file: make expands a recipe before the shell sees it, so a '$' in an
# option is make's long before it is anybody else's.  That is exactly
# right for the command line the tree is configured with -- a
# "--env PATH=/opt/bin:$(PATH)" is worth writing because make expands
# it -- and exactly wrong here, where what has to be written down is
# the option somebody wrote.  Recorded expanded, the file would hold
# whatever the variable happened to be worth on the day, and the rule
# that exists to notice an option changing would notice the variable
# changing instead.
#
# "$(notdir one/two)" is picked because its expansion says so: it
# comes out "two", which is a word that appears nowhere else in this
# option and could only have got into the file one way.
cat >expected-nested-opts <<'EOF'
--env FOO=child/x
--env BAR=$(notdir one/two)
--target more
EOF

# Built from the top, which is the spelling the parent's Makefile is
# for.
make $MAKE_ARGS > nested.out
cat nested.out
diff expected-nested-opts child/obj/vend/build-opts

# And built from inside the subproject, which is the other half of what
# that Makefile promises: the variable defaults to nothing down here,
# so a recipe that leaned on it says something else.
#
# The file must come out of this untouched rather than merely correct.
# Rewriting it with the same text would still be the rule reporting
# that the options had moved, and what hangs off that is a rebuild of
# the vendored tree -- so the mtime is the assertion, and the contents
# are there to say what went wrong when it fails.
touch before-nested-child
sleep 2s

(cd child && make $MAKE_ARGS -f obj/Makefile.child obj/vend/build-opts)
diff expected-nested-opts child/obj/vend/build-opts
find child/obj/vend/build-opts -newer before-nested-child > nested-moved.txt
cat nested-moved.txt
test ! -s nested-moved.txt

##############################################################################
# Saying no                                                                  #
##############################################################################
# A MAKEOPS written below the --generator that made it meaningless is
# refused where it stands, by run_by_make().
mkdir -p $top/makeops-after
fake_tree $top/makeops-after/sub

cat >$top/makeops-after/Configfile <<'EOF'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += sub
CONFIGUREOPTS += --generator Ninja
MAKEOPS       += MY_VAR=x
EOF

if (cd $top/makeops-after && $PTEST_BINARY $PCONFIGURE_ARGS) > after.out 2>&1
then
    exit 1
fi
cat after.out
grep -q "MAKEOPS doesn't apply to a cmake subproject: 'MY_VAR=x'" after.out
grep -q "there is no make being run here" after.out

# Nothing was written before it gave up, so there is no half-configured
# project left behind to confuse the next run.
test ! -e $top/makeops-after/Makefile

# The same mistake written the other way round can't be caught there:
# when the MAKEOPS arrives nothing yet knows what the generator will
# be.  So it's caught when the rules are written, which is loud in a
# different place rather than quiet.
mkdir -p $top/makeops-before
fake_tree $top/makeops-before/sub

cat >$top/makeops-before/Configfile <<'EOF'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += sub
MAKEOPS       += MY_VAR=x
CONFIGUREOPTS += --generator Ninja
EOF

if (cd $top/makeops-before && $PTEST_BINARY $PCONFIGURE_ARGS) > before.out 2>&1
then
    exit 1
fi
cat before.out
grep -q "MAKEOPS 'MY_VAR=x' has no make to go on the command line of" before.out
grep -q "the 'Ninja' generator doesn't build by running one" before.out
grep -q "so write '--define NAME=VALUE'" before.out

# And a --jobs for a build that is a sub-make, which is the same
# mistake from the other end: a sub-make takes its parallelism from
# the make that ran it, so a number of its own is how a "make -j8"
# turns into sixty-four compilers.  Told rather than ignored, since a
# number that silently did nothing would be read by the next person as
# the reason the build is slow.
mkdir -p $top/jobs
fake_tree $top/jobs/sub

cat >$top/jobs/Configfile <<'EOF'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += sub
CONFIGUREOPTS += --jobs 8
EOF

if (cd $top/jobs && $PTEST_BINARY $PCONFIGURE_ARGS) > jobs.out 2>&1
then
    exit 1
fi
cat jobs.out
grep -q "'--jobs 8' has no build of its own to run" jobs.out
grep -q "the 'Unix Makefiles' generator builds by running make" jobs.out
grep -q "run 'make -j8' instead" jobs.out

# And a --jobs that isn't a number of anything, which is refused where
# the option arrives rather than where the rules are written.  The
# digits are the whole of what makes it safe to paste that value onto a
# command line without quoting it, so the check on them is load-bearing
# and wants an assertion of its own -- without this the check could be
# deleted outright and nothing in this file would notice.  Said under a
# generator that has a build of its own so that what refuses it is the
# digits rather than the paragraph above.
mkdir -p $top/jobs-word
fake_tree $top/jobs-word/sub

cat >$top/jobs-word/Configfile <<'EOF'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += sub
CONFIGUREOPTS += --generator Ninja
CONFIGUREOPTS += --jobs lots
EOF

if (cd $top/jobs-word && $PTEST_BINARY $PCONFIGURE_ARGS) > jobs-word.out 2>&1
then
    exit 1
fi
cat jobs-word.out
grep -q "'--jobs lots' isn't a number of jobs" jobs-word.out
grep -q "it should look like '--jobs 8'" jobs-word.out
test ! -e $top/jobs-word/Makefile

# Where the tree installs is the one thing a cache variable may not
# say here: it is the same string in the cache, in the install and in
# whatever a SUBPROJECT_TARGETS names, so a second answer wins in the
# cache and loses everywhere else.
#
# Every spelling of it, because a refusal that covers one is a refusal
# somebody walks round without meaning to.  The install runs during
# "make", so what is on the other side of each of these is a plain
# "make" writing wherever the line pointed -- "/usr/local" is one
# character away from every one of them.
#
# Each of these is here because deleting the check that catches it
# leaves the rest of this file green.
installs_elsewhere()
{
    mkdir -p $top/$1
    fake_tree $top/$1/sub

    {
        echo "BUILD_SYSTEMS += cmake"
        echo ""
        echo "SUBPROJECTS   += sub"
        echo "$2"
    } > $top/$1/Configfile
    cat $top/$1/Configfile

    if (cd $top/$1 && $PTEST_BINARY $PCONFIGURE_ARGS) > $top/$1.out 2>&1
    then
        exit 1
    fi
    cat $top/$1.out

    grep -q "which says where the tree installs to" $top/$1.out
    grep -q "write '--prefix DIR' instead" $top/$1.out

    # A configure that stopped wrote no Makefile.  Half a Makefile is
    # worse than none at all, since make would go ahead and use it.
    test ! -e $top/$1/Makefile
}

# The cache variable this build system writes itself, said a second
# time.
installs_elsewhere prefix-define \
    "CONFIGUREOPTS += --define CMAKE_INSTALL_PREFIX=/opt/thing"
grep -q "sets 'CMAKE_INSTALL_PREFIX'" $top/prefix-define.out

# And the same variable through the option that reaches cmake's
# command line raw.  This is the widest way round the check above --
# a --configure-arg goes on last, and the last -D is the one cmake
# keeps -- so a refusal that only watched --define was a refusal one
# option long.
installs_elsewhere prefix-arg \
    "CONFIGUREOPTS += --configure-arg -DCMAKE_INSTALL_PREFIX=/opt/thing"
grep -q "sets 'CMAKE_INSTALL_PREFIX'" $top/prefix-arg.out

# With the "-D" as a word of its own, which cmake also accepts.  One
# option is several arguments here, since a --configure-arg is written
# the way it will appear on the command line.
installs_elsewhere prefix-arg-split \
    "CONFIGUREOPTS += --configure-arg -D CMAKE_INSTALL_PREFIX=/opt/thing"
grep -q "sets 'CMAKE_INSTALL_PREFIX'" $top/prefix-arg-split.out

# And the same list read backwards: "-U" deletes a cache variable, it
# is processed after the "-D" that set it, and what it deletes here is
# the prefix this build system wrote -- leaving cmake's own default,
# which is "/usr/local", installed into by a plain "make".  Nothing
# about the word says it is a destination; the name inside it does,
# which is why the names are what this refuses.
installs_elsewhere prefix-unset \
    "CONFIGUREOPTS += --configure-arg -UCMAKE_INSTALL_PREFIX"
grep -q "sets 'CMAKE_INSTALL_PREFIX'" $top/prefix-unset.out

# And the same variable with the shell's quoting through it.  A
# --configure-arg reaches the recipe unquoted -- that is what the
# option is for -- so the shell reads it before cmake does and the
# first thing it does is take the quotes off.  Written as text this is
# a cache variable called '"CMAKE_INSTALL_PREFIX"', which is a name
# nothing here has an opinion about; written as cmake receives it, it
# is the prefix.
installs_elsewhere prefix-quoted \
    'CONFIGUREOPTS += --configure-arg -D"CMAKE_INSTALL_PREFIX"=/opt'
grep -q "sets 'CMAKE_INSTALL_PREFIX'" $top/prefix-quoted.out

# And a name make works out, which is a name this has nothing to
# compare: the '$(NOTHING)' is an empty variable and what reaches
# cmake is the prefix with nothing in front of it.
mkdir -p $top/prefix-computed
fake_tree $top/prefix-computed/sub

{
    echo "BUILD_SYSTEMS += cmake"
    echo ""
    echo "SUBPROJECTS   += sub"
    echo 'CONFIGUREOPTS += --configure-arg $(NOTHING)-DCMAKE_INSTALL_PREFIX=/usr/local'
} > $top/prefix-computed/Configfile
cat $top/prefix-computed/Configfile

if (cd $top/prefix-computed && $PTEST_BINARY $PCONFIGURE_ARGS) \
    > $top/prefix-computed.out 2>&1
then
    exit 1
fi
cat $top/prefix-computed.out
grep -q "sets a variable whose name make works out" $top/prefix-computed.out
grep -q "write the variable out" $top/prefix-computed.out
test ! -e $top/prefix-computed/Makefile

# "-U" takes a glob rather than a name -- cmake's own manual says so --
# and it is processed after the "-D" that set the prefix, so a glob
# that matches CMAKE_INSTALL_PREFIX takes this build system's own
# answer back off the cache and leaves cmake's default standing.
# Confirmed against the real cmake this was built with: configuring a
# tree with "-DCMAKE_INSTALL_PREFIX=<scratch dir>" and then
# "-UCMAKE_INSTALL_P*" leaves CMAKE_INSTALL_PREFIX reading
# "/usr/local" in the cache, cmake's own compiled-in default, with the
# scratch directory never mentioned again.
mkdir -p $top/prefix-glob-unset
fake_tree $top/prefix-glob-unset/sub

{
    echo "BUILD_SYSTEMS += cmake"
    echo ""
    echo "SUBPROJECTS   += sub"
    echo "CONFIGUREOPTS += --configure-arg -UCMAKE_INSTALL_P*"
} > $top/prefix-glob-unset/Configfile
cat $top/prefix-glob-unset/Configfile

if (cd $top/prefix-glob-unset && $PTEST_BINARY $PCONFIGURE_ARGS) \
    > $top/prefix-glob-unset.out 2>&1
then
    exit 1
fi
cat $top/prefix-glob-unset.out
grep -q "name is not the text written down" $top/prefix-glob-unset.out
grep -q "'CMAKE_INSTALL_P\*'" $top/prefix-glob-unset.out
test ! -e $top/prefix-glob-unset/Makefile

# And a name that is not the text written down for a different reason:
# a "--configure-arg" is pasted into its recipe unquoted, so bash --
# SHELL=/bin/bash, per src/libmakefile/makefile.c++ -- reads it before
# cmake ever does, and brace expansion turns
# "CMAKE_INSTALL_PRE{F,F}IX" into "CMAKE_INSTALL_PREFIX" said twice
# before this or cmake sees either copy.  Confirmed against the real
# cmake this was built with: run outside of quotes, so bash's own
# expansion is the one that acts on it,
# "-DCMAKE_INSTALL_PREFIX=<other dir> -DCMAKE_INSTALL_PRE{F,F}IX=<scratch dir>"
# leaves CMAKE_INSTALL_PREFIX in the cache reading the scratch
# directory -- the second, brace-expanded "-D" is the one cmake kept.
mkdir -p $top/prefix-brace
fake_tree $top/prefix-brace/sub

{
    echo "BUILD_SYSTEMS += cmake"
    echo ""
    echo "SUBPROJECTS   += sub"
    echo "CONFIGUREOPTS += --configure-arg -DCMAKE_INSTALL_PRE{F,F}IX=/tmp/pconfigure-elsewhere"
} > $top/prefix-brace/Configfile
cat $top/prefix-brace/Configfile

if (cd $top/prefix-brace && $PTEST_BINARY $PCONFIGURE_ARGS) \
    > $top/prefix-brace.out 2>&1
then
    exit 1
fi
cat $top/prefix-brace.out
grep -q "name is not the text written down" $top/prefix-brace.out
grep -qF "'CMAKE_INSTALL_PRE{F,F}IX'" $top/prefix-brace.out
test ! -e $top/prefix-brace/Makefile

# The same brace by itself, with no "-D" in front of it and no '='
# after it -- proving the refusal is unconditional rather than tied to
# the "-D...=..." shape above.  "-B" takes whatever is glued to it, so
# a "-B{,}" would already be caught by the whole-word check further
# down; a bare name is the shape that check does not see.
mkdir -p $top/brace-bare
fake_tree $top/brace-bare/sub

{
    echo "BUILD_SYSTEMS += cmake"
    echo ""
    echo "SUBPROJECTS   += sub"
    echo "CONFIGUREOPTS += --configure-arg -DCMAKE_INSTALL_{PREFIX,PREFIX}"
} > $top/brace-bare/Configfile
cat $top/brace-bare/Configfile

if (cd $top/brace-bare && $PTEST_BINARY $PCONFIGURE_ARGS) \
    > $top/brace-bare.out 2>&1
then
    exit 1
fi
cat $top/brace-bare.out
grep -q "name is not the text written down" $top/brace-bare.out
test ! -e $top/brace-bare/Makefile

# Legitimate use of a raw "--configure-arg" is not collateral damage:
# make's own "$(abspath ...)" -- the escape hatch
# checked_project_path()'s own comment points to for a value that
# really does have to be computed -- still has to work, since it has
# none of '{', '}', '*', '?', '[' or '`' in it anywhere.
mkdir -p $top/brace-legit
fake_tree $top/brace-legit/sub
echo "not-really-cmake" > $top/brace-legit/tc.cmake

{
    echo "BUILD_SYSTEMS += cmake"
    echo ""
    echo "SUBPROJECTS   += sub"
    echo 'CONFIGUREOPTS += --configure-arg --toolchain $(abspath tc.cmake)'
} > $top/brace-legit/Configfile
cat $top/brace-legit/Configfile

(cd $top/brace-legit && $PTEST_BINARY $PCONFIGURE_ARGS)
test -f $top/brace-legit/Makefile
grep -qF -- '--toolchain $(abspath tc.cmake)' $top/brace-legit/Makefile

# And cmake's own spelling of it, which takes the directory in the
# word after the flag.
installs_elsewhere prefix-flag \
    "CONFIGUREOPTS += --configure-arg --install-prefix /opt/thing"
grep -q "sets 'install-prefix'" $top/prefix-flag.out
grep -q "cmake's own spelling of CMAKE_INSTALL_PREFIX" $top/prefix-flag.out

# CMAKE_STAGING_PREFIX is the one a list of GNUInstallDirs plus
# CMAKE_INSTALL_PREFIX misses, and it is the worst one to miss: it is
# documented as where to install when the real prefix has to stay
# pristine, so it beats the prefix outright.  Every install() lands
# under it, the cache goes on saying the prefix this build system
# wrote, and the directory a SUBPROJECT_TARGETS is named from stays
# empty.
installs_elsewhere staging-define \
    "CONFIGUREOPTS += --define CMAKE_STAGING_PREFIX=/opt/staging"
grep -q "sets 'CMAKE_STAGING_PREFIX'" $top/staging-define.out

installs_elsewhere staging-arg \
    "CONFIGUREOPTS += --configure-arg -DCMAKE_STAGING_PREFIX=/opt/staging"
grep -q "sets 'CMAKE_STAGING_PREFIX'" $top/staging-arg.out

# And DESTDIR, which is none of cmake's business and all of make's:
# it is read while the install is running and pasted onto the front of
# everything else, so it is the one of these a MAKEOPS can say.
installs_elsewhere destdir-makeops "MAKEOPS       += DESTDIR=/usr/local"
grep -q "sets 'DESTDIR'" $top/destdir-makeops.out

# And the fourth spelling of DESTDIR, which is the environment -- the
# place the install script cmake generates reads it from in the first
# place.  It was refused as a --define, as a --configure-arg and as a
# MAKEOPS and taken here, which is worse than never having refused it:
# three closed doors and an open one read as a closed door, and what
# came through this one was every file the tree installs, written
# under whatever it pointed at, on a plain "make".
installs_elsewhere destdir-env \
    "CONFIGUREOPTS += --env DESTDIR=/tmp/stage"
grep -q "sets 'DESTDIR'" $top/destdir-env.out

##############################################################################
# Where part of the install goes is the same question one level down   #
##############################################################################
# GNUInstallDirs is the module every project that installs in the GNU
# layout includes, and each of its variables says where one kind of
# file lands under the prefix.  An absolute value moves that kind out
# from under the prefix entirely -- so the programs go to
# /usr/local/bin with the prefix left exactly as this build system
# wrote it.
#
# A relative one can't: install() joins a relative DESTINATION to
# CMAKE_INSTALL_PREFIX, so the files stay inside the directory the
# rest of this build reads from.  So these are refused by what they
# were given rather than by name, which is the difference between
# "you may not move the install" and "you may not choose the layout".
moves_the_install()
{
    mkdir -p $top/$1
    fake_tree $top/$1/sub

    {
        echo "BUILD_SYSTEMS += cmake"
        echo ""
        echo "SUBPROJECTS   += sub"
        echo "$2"
    } > $top/$1/Configfile
    cat $top/$1/Configfile

    if (cd $top/$1 && $PTEST_BINARY $PCONFIGURE_ARGS) > $top/$1.out 2>&1
    then
        exit 1
    fi
    cat $top/$1.out

    grep -q "sets '$3', which says where part of the install goes" \
        $top/$1.out
    grep -q "a relative value is read under the prefix and can't leave it" \
        $top/$1.out
    test ! -e $top/$1/Makefile
}

moves_the_install bindir-define \
    "CONFIGUREOPTS += --define CMAKE_INSTALL_BINDIR=/usr/local/bin" \
    CMAKE_INSTALL_BINDIR

moves_the_install libdir-arg \
    "CONFIGUREOPTS += --configure-arg -DCMAKE_INSTALL_LIBDIR=/usr/local/lib" \
    CMAKE_INSTALL_LIBDIR

# The two ways a relative value climbs out anyway, which are the same
# two checked_project_path() refuses of a path pconfigure has to
# resolve itself: a ".." walks up out of the prefix, and a '$' is a
# make expansion that becomes either of the other two after the last
# thing here has looked at it.
moves_the_install libdir-climb \
    "CONFIGUREOPTS += --define CMAKE_INSTALL_LIBDIR=../../../../lib" \
    CMAKE_INSTALL_LIBDIR

moves_the_install libdir-expansion \
    'CONFIGUREOPTS += --define CMAKE_INSTALL_LIBDIR=$(HOME)/lib' \
    CMAKE_INSTALL_LIBDIR

# And the two ways the shell hands cmake an absolute path that wasn't
# one when it was written: quotes around it, and a backslash in front
# of the '/' that would have given it away.  Both of them reach the
# recipe through a --configure-arg, which goes on unquoted, and both
# of them are gone by the time cmake reads the word.
moves_the_install libdir-quoted \
    'CONFIGUREOPTS += --define CMAKE_INSTALL_LIBDIR="/usr/local/lib"' \
    CMAKE_INSTALL_LIBDIR

moves_the_install libdir-escaped \
    'CONFIGUREOPTS += --configure-arg -DCMAKE_INSTALL_LIBDIR=\/usr\/local\/lib' \
    CMAKE_INSTALL_LIBDIR

# And one that isn't a path at all.  This is why what a value may be
# is written out rather than what it may not: a --configure-arg
# reaches the recipe unquoted, so a ';' in it ends the command the
# recipe was running and hands the shell whatever came after it -- and
# a cmake list is semicolon-separated, which is exactly why somebody
# would write one here.  A check that watched for a leading '/', a
# '..' and a '$' let this straight through.
moves_the_install libdir-list \
    'CONFIGUREOPTS += --configure-arg -DCMAKE_INSTALL_LIBDIR=lib;lib64' \
    CMAKE_INSTALL_LIBDIR

# A type on the variable doesn't change which variable it is, and a
# "-D" that carries one is the spelling somebody reaches for when the
# plain one has been refused.
moves_the_install libdir-typed \
    "CONFIGUREOPTS += --define CMAKE_INSTALL_LIBDIR:PATH=/usr/local/lib" \
    CMAKE_INSTALL_LIBDIR

# And the relative one, which is taken -- and taken all the way to the
# install, since a refusal that accepted the line and then wrote the
# prefix into the recipe without it would be a layout nobody asked
# for.  "--prefix DIR" cannot say this, which is exactly why refusing
# it outright would be a refusal with no honest advice to offer.
mkdir -p $top/libdir-relative
fake_tree $top/libdir-relative/sub

cat >$top/libdir-relative/Configfile <<'EOF'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += sub
CONFIGUREOPTS += --define CMAKE_INSTALL_LIBDIR=lib/mine
SUBPROJECT_TARGETS += lib/mine/libtool.a
EOF

(cd $top/libdir-relative && $PTEST_BINARY $PCONFIGURE_ARGS)
(cd $top/libdir-relative && make)

# Under the prefix, which is where a relative DESTINATION is read
# from, and named by the SUBPROJECT_TARGETS that waited for it.
test -f $top/libdir-relative/obj/sub/prefix/lib/mine/libtool.a

##############################################################################
# Which tree gets configured, and where, are said once too                   #
##############################################################################
# The install escape one option across.  A --configure-arg is pasted
# on after everything this build system wrote and cmake keeps the last
# "-B" it is handed, so a second one configures without a murmur and
# leaves a whole cmake build tree wherever it pointed -- one that
# nothing in this project ever removes, because the configure rule's
# "rm -fr" and "make distclean" both name the directory cmake didn't
# use.  "-S" is one word over and builds a tree no SUBPROJECTS named.
said_twice()
{
    mkdir -p $top/$1
    fake_tree $top/$1/sub

    {
        echo "BUILD_SYSTEMS += cmake"
        echo ""
        echo "SUBPROJECTS   += sub"
        echo "$2"
    } > $top/$1/Configfile
    cat $top/$1/Configfile

    if (cd $top/$1 && $PTEST_BINARY $PCONFIGURE_ARGS) > $top/$1.out 2>&1
    then
        exit 1
    fi
    cat $top/$1.out

    grep -q "sets '$3'" $top/$1.out
    grep -q "a SUBPROJECTS says which tree gets built" $top/$1.out
    test ! -e $top/$1/Makefile
}

said_twice build-dir \
    "CONFIGUREOPTS += --configure-arg -B /tmp/pconfigure-elsewhere" -B
grep -q "says where the tree builds" $top/build-dir.out

# Glued to its value, which is how a one-letter option usually
# arrives and is the spelling a check that compared whole words would
# miss.
said_twice build-dir-glued \
    "CONFIGUREOPTS += --configure-arg -B/tmp/pconfigure-elsewhere" -B

said_twice source-dir \
    "CONFIGUREOPTS += --configure-arg -S /tmp/pconfigure-other-tree" -S
grep -q "says which tree gets configured" $top/source-dir.out

# A cache variable whose name merely looks like one of those is not
# one of them.  CMAKE_INSTALL_RPATH says what to link with rather than
# where to put it, and a check written as "anything starting with
# CMAKE_INSTALL_" would take it -- which is a refusal of an option
# somebody had every right to write.  The other two are the shapes
# that a name matched by its prefix would take if the rule were read
# backwards.
mkdir -p $top/rpath-define
fake_tree $top/rpath-define/sub

cat >$top/rpath-define/Configfile <<'EOF'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += sub
CONFIGUREOPTS += --define CMAKE_INSTALL_RPATH=$ORIGIN/../lib
CONFIGUREOPTS += --define CMAKE_INSTALL_MESSAGE=LAZY
CONFIGUREOPTS += --define CMAKE_INSTALL_PREFIXES=/opt/a
CONFIGUREOPTS += --configure-arg -Wno-dev
CONFIGUREOPTS += --configure-arg --toolchain /opt/tc.cmake
CONFIGUREOPTS += --configure-arg --toolchain $(abspath tc.cmake)
CONFIGUREOPTS += --define CMAKE_INSTALL_LIBDIR="lib64"
EOF

(cd $top/rpath-define && $PTEST_BINARY $PCONFIGURE_ARGS)
test -f $top/rpath-define/Makefile

# A --define with nothing after the name is a cache variable with no
# value, which the manual says is refused and nothing asserted on
# until now: cmake reads "-DNAME" as setting NAME to the empty string,
# so what a Configfile line that meant to say something would get is a
# variable quietly emptied.
mkdir -p $top/define-value
fake_tree $top/define-value/sub

cat >$top/define-value/Configfile <<'EOF'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += sub
CONFIGUREOPTS += --define LLVM_TARGETS_TO_BUILD
EOF

if (cd $top/define-value && $PTEST_BINARY $PCONFIGURE_ARGS) \
    > $top/define-value.out 2>&1
then
    exit 1
fi
cat $top/define-value.out
grep -q "'--define LLVM_TARGETS_TO_BUILD' has no value" $top/define-value.out
grep -q "'--define LLVM_TARGETS_TO_BUILD=RISCV'" $top/define-value.out
test ! -e $top/define-value/Makefile

# And a prefix that make would expand, which is the hole a lexical
# check leaves open: a substitution reference has no slash in it, so
# it passes as one harmless-looking path component and the
# "$(abspath ...)" the prefix goes into expands it to whatever the
# variable held.  This one comes out as "obj/../../elsewhere".
mkdir -p $top/prefix-expansion
fake_tree $top/prefix-expansion/sub

cat >$top/prefix-expansion/Configfile <<'EOF'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += sub
CONFIGUREOPTS += --prefix obj/$(CURDIR:%=..)/$(CURDIR:%=..)/gone
EOF

if (cd $top/prefix-expansion && $PTEST_BINARY $PCONFIGURE_ARGS) \
    > $top/prefix-expansion.out 2>&1
then
    exit 1
fi
cat $top/prefix-expansion.out
grep -q "is a make expansion rather than a path" $top/prefix-expansion.out
test ! -e $top/prefix-expansion/Makefile

# A prefix is where a vendored tree installs to inside the project that
# vendored it, so an absolute one is either a way of installing into
# /usr/local during a plain "make" or a path no Makefile here can name.
# The diagnostic is the shared one -- three build systems ask this
# question and it has one answer -- so it says what to write instead,
# which is what every fatal error here owes whoever reads it.
mkdir -p $top/abs-prefix
fake_tree $top/abs-prefix/sub

cat >$top/abs-prefix/Configfile <<'EOF'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += sub
CONFIGUREOPTS += --prefix /usr/local
EOF

if (cd $top/abs-prefix && $PTEST_BINARY $PCONFIGURE_ARGS) > abs.out 2>&1
then
    exit 1
fi
cat abs.out
grep -q "'--prefix /usr/local' is an absolute path" abs.out
grep -q "read relative to the project that wrote it" abs.out
grep -q "like '--prefix obj/toolchain'" abs.out
test ! -e $top/abs-prefix/Makefile

# A prefix inside the object directory is what an install prefix is.
# What goes in the Makefile because of it is one line and only one:
# cache-clean is told not to look in there.  "make cache-clean" empties
# an object directory of everything the Makefile can't say it builds,
# and an install a vendored tree did is the whole of what it can't say
# -- what would survive is whatever a SUBPROJECT_TARGETS named and
# nothing else, behind a build stamp that still says the tree is
# built, so nothing puts the rest back and the first thing to go wrong
# is a compile against a header that was there yesterday.
#
# distclean says nothing about it, which is the other half of the same
# design and the half worth asserting: distclean removes the object
# directory, the prefix is inside the object directory, so the prefix
# goes without a line of its own.  A line of its own would be a path
# out of a Configfile pasted into an "rm -rf", and the only reason to
# write one would be a prefix that could be somewhere else.
mkdir -p $top/obj-prefix
fake_tree $top/obj-prefix/sub

cat >$top/obj-prefix/Configfile <<'EOF'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += sub
CONFIGUREOPTS += --prefix obj/toolchain
EOF

(cd $top/obj-prefix && $PTEST_BINARY $PCONFIGURE_ARGS)
grep -q -- "'-DCMAKE_INSTALL_PREFIX=\$(abspath obj/toolchain)'" \
    $top/obj-prefix/Makefile
grep -q -- "-not -path 'obj/toolchain/[*]'" $top/obj-prefix/Makefile

sed -n '/^distclean:/,/^$/p' $top/obj-prefix/Makefile > obj-distclean.rule
cat obj-distclean.rule
grep -q "rm -rf 'obj'$" obj-distclean.rule
if grep -q "rm -rf 'obj/toolchain'" obj-distclean.rule
then
    exit 1
fi

# And one with an apostrophe in it, which the rule about where a
# prefix may point has nothing to say about: it is a directory inside
# the object directory, so it is a prefix, and somebody whose checkout
# sits under a directory named after them has not made a mistake.
#
# It gets a fixture of its own because it is the one path in a
# cache-clean that a Configfile author wrote by hand -- every other
# directory that command is told to leave alone is a name pconfigure
# made up, and a name pconfigure made up has no apostrophe in it.
# Built by putting a pair of apostrophes around the directory, a
# directory carrying one of its own closes that pair early and hands
# the rest of the line to the shell, so "make cache-clean" stops with
# "unexpected EOF while looking for matching" from the command whose
# entire job was to leave the install alone.
#
# Running it is the assertion, and the characters in the Makefile are
# checked as well because the two failures look different: a Makefile
# with the wrong characters in it and a shell that choked on them is
# one bug, and a Makefile that reads correctly while cache-clean
# reclaims the prefix anyway would be another.
mkdir -p $top/quoted-prefix
fake_tree $top/quoted-prefix/sub

cat >$top/quoted-prefix/Configfile <<'EOF'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += sub
CONFIGUREOPTS += --prefix obj/it's
EOF

(cd $top/quoted-prefix && $PTEST_BINARY $PCONFIGURE_ARGS)

# Written out to a file and matched whole rather than spelled inline,
# since a pattern with this many apostrophes in it is a pattern the
# shell reading this test has an opinion about too.
cat >quoted-prune <<'EOF'
-not -path 'obj/it'\''s/*'
EOF
cat quoted-prune
grep -q -F -f quoted-prune $top/quoted-prefix/Makefile

(cd $top/quoted-prefix && make $MAKE_ARGS cache-clean)

# The object directory itself is inside itself and is still not a
# directory inside it: cache-clean spares an install prefix, so a
# prefix that is the whole object directory is a cache-clean that
# reclaims nothing at all and says nothing about it.
mkdir -p $top/objdir-prefix
fake_tree $top/objdir-prefix/sub

cat >$top/objdir-prefix/Configfile <<'EOF'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += sub
CONFIGUREOPTS += --prefix obj
EOF

if (cd $top/objdir-prefix && $PTEST_BINARY $PCONFIGURE_ARGS) > objdir.out 2>&1
then
    exit 1
fi
cat objdir.out
grep -q "'--prefix obj' is the object directory itself" objdir.out
grep -q "make cache-clean" objdir.out
grep -q "like '--prefix obj/toolchain'" objdir.out
test ! -e $top/objdir-prefix/Makefile

# And anywhere outside it is refused whatever is there, which is the
# point: what is outside an object directory is somebody's checkout,
# and pconfigure has no way of knowing whose.  The vendored tree is
# the one somebody reaches for, since it is right there beside the
# Configfile.
mkdir -p $top/tree-prefix
fake_tree $top/tree-prefix/sub

cat >$top/tree-prefix/Configfile <<'EOF'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += sub
CONFIGUREOPTS += --prefix sub/staging
EOF

if (cd $top/tree-prefix && $PTEST_BINARY $PCONFIGURE_ARGS) > tree.out 2>&1
then
    exit 1
fi
cat tree.out
grep -q "names 'sub/staging', which is outside 'obj'" tree.out
grep -q "write a directory inside 'obj'" tree.out
test ! -e $top/tree-prefix/Makefile

# Said the long way round, the default is still allowed: a prefix
# inside this build system's own output directory.
mkdir -p $top/own-prefix
fake_tree $top/own-prefix/sub

cat >$top/own-prefix/Configfile <<'EOF'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += sub
CONFIGUREOPTS += --prefix obj/sub/prefix/staging
EOF

(cd $top/own-prefix && $PTEST_BINARY $PCONFIGURE_ARGS)
grep -q -- "'-DCMAKE_INSTALL_PREFIX=\$(abspath obj/sub/prefix/staging)'" \
    $top/own-prefix/Makefile

# A prefix that climbs out of the project is a path no Makefile here
# owns: it would have to mean one thing to a make run in the project
# and another to a make run above it.
mkdir -p $top/up-prefix
fake_tree $top/up-prefix/sub

cat >$top/up-prefix/Configfile <<'EOF'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += sub
CONFIGUREOPTS += --prefix ../outside
EOF

if (cd $top/up-prefix && $PTEST_BINARY $PCONFIGURE_ARGS) > up.out 2>&1
then
    exit 1
fi
cat up.out
grep -q "'--prefix ../outside' reaches outside the project that wrote it" up.out
grep -q "like '--prefix obj/toolchain'" up.out
test ! -e $top/up-prefix/Makefile

##############################################################################
# One Configfile line, one directory                                         #
##############################################################################
# A subproject's Configfile is read twice over its life: once by a
# pconfigure run at the top of the tree, and once by a pconfigure run
# inside the subproject itself -- the subproject's Makefile is written
# to be run from in there, and the section above exercises it.  A path
# in that Configfile has to name the same directory both times, or the
# same configuration builds two different trees depending on who asked.
#
# The rule that makes it so is that a path is read relative to the
# project that wrote it and may not climb out of it.  What that buys
# is below: the prefix is the child's own object directory from
# inside, and the child's object directory named through the child's
# prefix variable from above.
mkdir -p $top/nested/sub
fake_tree $top/nested/sub/vend

cat >$top/nested/Configfile <<'EOF'
SUBPROJECTS += sub
EOF

cat >$top/nested/sub/Configfile <<'EOF'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += vend
CONFIGUREOPTS += --prefix obj/toolchain
EOF

(cd $top/nested && $PTEST_BINARY $PCONFIGURE_ARGS)
cat $top/nested/sub/obj/Makefile.sub
grep -q -- \
    "'-DCMAKE_INSTALL_PREFIX=\$(abspath \$(pconfigure_subdir_sub)obj/toolchain)'" \
    $top/nested/sub/obj/Makefile.sub

(cd $top/nested/sub && $PTEST_BINARY $PCONFIGURE_ARGS)
cat $top/nested/sub/Makefile
grep -q -- "'-DCMAKE_INSTALL_PREFIX=\$(abspath obj/toolchain)'" \
    $top/nested/sub/Makefile

# And a path that climbs out is refused from both directions, which is
# the assertion that matters: resolving it before asking would turn
# the child's "../obj/toolchain" into the parent's "obj/toolchain" --
# a path that climbs out of nothing, that the parent would accept, and
# that names a directory belonging to a project which never wrote the
# line.
mkdir -p $top/nested-up/sub
fake_tree $top/nested-up/sub/vend

cat >$top/nested-up/Configfile <<'EOF'
SUBPROJECTS += sub
EOF

cat >$top/nested-up/sub/Configfile <<'EOF'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += vend
CONFIGUREOPTS += --prefix ../obj/toolchain
EOF

if (cd $top/nested-up && $PTEST_BINARY $PCONFIGURE_ARGS) > nested-up.out 2>&1
then
    exit 1
fi
cat nested-up.out
grep -q "'--prefix ../obj/toolchain' reaches outside the project" nested-up.out
test ! -e $top/nested-up/Makefile

if (cd $top/nested-up/sub && $PTEST_BINARY $PCONFIGURE_ARGS) \
    > nested-up-in.out 2>&1
then
    exit 1
fi
cat nested-up-in.out
grep -q "'--prefix ../obj/toolchain' reaches outside the project" \
    nested-up-in.out
test ! -e $top/nested-up/sub/Makefile

# An option nobody recognized says so, and then says what would have
# been recognized: an unknown flag is almost always a flag spelled
# another build system's way.
mkdir -p $top/unknown
fake_tree $top/unknown/sub

cat >$top/unknown/Configfile <<'EOF'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += sub
CONFIGUREOPTS += --defconfig tiny
EOF

if (cd $top/unknown && $PTEST_BINARY $PCONFIGURE_ARGS) > unknown.out 2>&1
then
    exit 1
fi
cat unknown.out
grep -q "cmake: unknown CONFIGUREOPTS '--defconfig tiny'" unknown.out
grep -q "'--define VAR=VALUE' sets a cache variable" unknown.out
grep -q "'--generator NAME' picks the build system cmake writes" unknown.out
test ! -e $top/unknown/Makefile

##############################################################################
# An --env is a shell assignment or it is nothing                            #
##############################################################################
# The name in front of the '=' is the one piece of a CONFIGUREOPTS
# that reaches a recipe unquoted, and it has to be: quoted, it stops
# being a shell assignment and becomes the name of a program nobody
# has.  This build system asked only whether there was an '=' in the
# line at all, so the same line another build system refused was taken
# here and turned into an Error 127 in the middle of a build.
mkdir -p $top/bad-env
fake_tree $top/bad-env/sub

cat >$top/bad-env/Configfile <<'EOF'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += sub
CONFIGUREOPTS += --env 2FOO=bar
EOF

if (cd $top/bad-env && $PTEST_BINARY $PCONFIGURE_ARGS) > bad-env.out 2>&1
then
    exit 1
fi
cat bad-env.out
grep -q "'--env 2FOO=bar' doesn't start with a variable name" bad-env.out
grep -q "the one part of this that can't be quoted" bad-env.out
test ! -e $top/bad-env/Makefile

##############################################################################
# A prefix inside the part of the object directory this project uses         #
##############################################################################
# Owning every byte of an object directory is what lets a prefix be in
# there at all; it is not the same as having none of it spoken for.
# "obj/src" is where the objects this project compiles land, and "make
# cache-clean" spares an install prefix whole -- so a prefix here is a
# cache-clean that reclaims none of the cache it exists to reclaim,
# and says nothing about it, since it runs and finishes exactly as it
# would have.
mkdir -p $top/own-obj
fake_tree $top/own-obj/sub

cat >$top/own-obj/Configfile <<'EOF'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += sub
CONFIGUREOPTS += --prefix obj/src
EOF

if (cd $top/own-obj && $PTEST_BINARY $PCONFIGURE_ARGS) > own-obj.out 2>&1
then
    exit 1
fi
cat own-obj.out
grep -q "names 'obj/src', which is where this project builds" own-obj.out
grep -q "like '--prefix obj/toolchain'" own-obj.out
test ! -e $top/own-obj/Makefile

exit 0
