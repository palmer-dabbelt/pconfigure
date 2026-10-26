#include "harness_start.bash"

top="$tempdir"

##############################################################################
# A meson and a ninja that aren't                                            #
##############################################################################
# The same bargain cmake.bash strikes: what's under test is the command
# line pconfigure writes and what happens to the files it names, not
# what meson does once it has been run.  So meson and ninja are shell
# scripts on the PATH that behave the same on a machine with neither,
# and that leave a log of how they were called.
#
# They live beside the fixture rather than inside it, so that nothing
# under "sub" is anything pconfigure might chase as a source.
mkdir -p $top/fake
export MESON_FAKE_LOG="$top/fake/ran.log"

cat >$top/fake/meson <<'EOF'
#!/bin/sh
set -e

echo "meson $*" >> "$MESON_FAKE_LOG"
echo "env MY_ENV=$MY_ENV" >> "$MESON_FAKE_LOG"

if [ "$1" != "setup" ]
then
    echo "meson: only 'setup' is faked, not '$1'" 1>&2
    exit 1
fi
shift

prefix=
positional=

while [ "$#" -gt 0 ]
do
    case "$1" in
    --prefix=*) prefix="${1#--prefix=}";        shift 1;;
    -D*|--*)                                    shift 1;;
    *)          positional="$positional $1";    shift 1;;
    esac
done

# Two positional arguments, the build directory and then the source
# directory, which is the whole of how a meson build stays out of the
# tree it builds.  Anything else is refused, so "nothing was written
# inside sub" is an assertion rather than a coincidence.
set -- $positional
if [ "$#" -ne 2 ]
then
    echo "meson: wanted a build and a source directory, got '$positional'" 1>&2
    exit 1
fi
build="$1"
source="$2"

if [ ! -f "$source/meson.build" ]
then
    echo "meson: '$source' has no meson.build in it" 1>&2
    exit 1
fi

mkdir -p "$build"
echo "$prefix" > "$build/prefix.txt"

# build.ninja last, the way the real one writes it: the rule pconfigure
# writes hangs off it, so it has to mean the setup finished.
echo "# fake" > "$build/build.ninja"
EOF
chmod +x $top/fake/meson

cat >$top/fake/ninja <<'EOF'
#!/bin/sh
set -e

echo "ninja $*" >> "$MESON_FAKE_LOG"

dir=
jobs=
target=
while [ "$#" -gt 0 ]
do
    case "$1" in
    -C) dir="$2";       shift 2;;
    -j) jobs="$2";      shift 2;;
    *)  target="$1";    shift 1;;
    esac
done

if [ ! -f "$dir/build.ninja" ]
then
    echo "ninja: '$dir' has no build.ninja in it" 1>&2
    exit 1
fi

# The target and the job count in brackets, since the whole of what the
# quoting around a target buys is whether it arrived as one argument.
echo "target=[$target] jobs=[$jobs]" >> "$dir/ninja-ran.txt"

case "$target" in
"")
    echo "MY_ENV=$MY_ENV" > "$dir/built.txt"
    ;;
install)
    # Three files where a SUBPROJECT_TARGETS names one, so a cleaning
    # target that kept only the named file would be caught.
    prefix="$(cat "$dir/prefix.txt")"
    mkdir -p "$prefix/bin" "$prefix/lib" "$prefix/include"
    echo "installed" > "$prefix/bin/tool"
    echo "installed" > "$prefix/lib/libtool.a"
    echo "installed" > "$prefix/include/tool.h"
    ;;
esac
EOF
chmod +x $top/fake/ninja

export PATH="$top/fake:$PATH"

fake_tree()
{
    mkdir -p "$1/src"

    cat >"$1/meson.build" <<'EOF'
project('tool', 'c')
executable('tool', 'src/tool.c', install: true)
EOF

    cat >"$1/src/tool.c" <<'EOF'
int main(void) { return 0; }
EOF
}

fake_tree $top/sub

# The fakes' refusals, taken on purpose once: each is a net under an
# assertion below, and a net nothing ever falls into is one nobody
# knows works.
if MESON_FAKE_LOG=$top/fake/probe.log $top/fake/meson setup $top/fake/scratch \
    > $top/fake/one-dir.out 2>&1
then
    exit 1
fi
grep -q "wanted a build and a source directory" $top/fake/one-dir.out

if MESON_FAKE_LOG=$top/fake/probe.log \
    $top/fake/meson setup $top/fake/scratch $top \
    > $top/fake/no-build-file.out 2>&1
then
    exit 1
fi
grep -q "has no meson.build in it" $top/fake/no-build-file.out
test ! -e $top/fake/scratch

if MESON_FAKE_LOG=$top/fake/probe.log $top/fake/ninja -C $top/fake/scratch \
    > $top/fake/no-ninja-file.out 2>&1
then
    exit 1
fi
grep -q "has no build.ninja in it" $top/fake/no-ninja-file.out

##############################################################################
# Configuring                                                                #
##############################################################################
# An array option is written with commas and spaces and a flags option
# with spaces, and each has to arrive as one argument.
cat >$top/Configfile <<'EOF'
BUILD_SYSTEMS += meson

SUBPROJECTS   += sub
CONFIGUREOPTS += --build-type release
CONFIGUREOPTS += --define targets=one, two
CONFIGUREOPTS += --define c_args=-g -O2
CONFIGUREOPTS += --env MY_ENV=one two
SUBPROJECT_TARGETS += bin/tool
EOF

cd $top
$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# Nothing was written inside the vendored tree.
test ! -e sub/build.ninja
test ! -e sub/build
test ! -e sub/obj

# Configure time writes the configure-side options and nothing else;
# the build-side ones are make's to write, out of the recipe that
# reads them.
test -f obj/sub/configure-opts
test ! -e obj/sub/build-opts
test ! -e obj/sub/build
test ! -e obj/sub/build-stamp

grep -q "^obj/sub/build/build.ninja: obj/sub/configure-opts$" Makefile
grep -q "^obj/sub/build-stamp:" Makefile
grep -q "^all: obj/sub/build-stamp$" Makefile
grep -q "^\.PHONY: obj/sub/build-opts-force$" Makefile
grep -q "^obj/sub/build-opts: obj/sub/build-opts-force$" Makefile

grep "^obj/sub/build-stamp:" Makefile > stamp.dep
cat stamp.dep
grep -q "obj/sub/build/build.ninja" stamp.dep
grep -q "obj/sub/build-opts" stamp.dep
grep -q -- "sub/[*]" stamp.dep
grep -q -- "sub/src/[*]" stamp.dep

awk '/^\t/ { if (p) print; next } { p = 0 } /^obj\/sub\/build\/build.ninja:/ { p = 1 }' Makefile > config.rule
cat config.rule

# Starting over, build directory and default prefix both.
grep -q "rm -fr obj/sub/build$" config.rule
grep -q "rm -fr obj/sub/prefix$" config.rule

# The prefix as "--prefix=", absolutely; the build type as a "-D"; each
# option one argument however many spaces and commas are in it; the
# build directory then the source directory; and the environment in
# front of the whole command with its value quoted and its name not.
grep -q -- "'--prefix=\$(abspath obj/sub/prefix)'" config.rule
grep -q -- "'-Dbuildtype=release'" config.rule
grep -q -- "'-Dtargets=one, two'" config.rule
grep -q -- "'-Dc_args=-g -O2'" config.rule
grep -q "MY_ENV='one two' meson setup .* obj/sub/build sub$" config.rule

awk '/^\t/ { if (p) print; next } { p = 0 } /^obj\/sub\/build-stamp:/ { p = 1 }' Makefile > stamp.rule
cat stamp.rule

# ninja directly rather than "meson compile", with no leading '+', and
# the install as the build directory's own target.  Both with DESTDIR
# out of the environment, which is where "meson install" reads it
# from: the install is part of building the tree, and a DESTDIR from
# the outer make would send it somewhere other than the prefix.
grep -q "env -u DESTDIR MY_ENV='one two' ninja -C obj/sub/build$" stamp.rule
grep -q "env -u DESTDIR MY_ENV='one two' ninja -C obj/sub/build 'install'$" stamp.rule
if grep -q "meson compile\|meson install\|^\s*@*+" stamp.rule
then
    exit 1
fi

##############################################################################
# Building                                                                   #
##############################################################################
make $MAKE_ARGS > first.out
cat first.out
cat $MESON_FAKE_LOG

test -f obj/sub/build/build.ninja
test -f obj/sub/build-stamp
test -f obj/sub/build-opts
test -f obj/sub/prefix/bin/tool
test -f obj/sub/prefix/lib/libtool.a
test -f obj/sub/prefix/include/tool.h
grep -q "^MY_ENV=one two$" obj/sub/build/built.txt

# Set up once, built once and installed once, in that order.
test "$(grep -c '^meson setup' $MESON_FAKE_LOG)" = 1
test "$(cat obj/sub/build/ninja-ran.txt)" = "target=[] jobs=[]
target=[install] jobs=[]"

# A tree that's built stays built.
cp $MESON_FAKE_LOG first.log
make $MAKE_ARGS > second.out
cat second.out
cmp first.log $MESON_FAKE_LOG

##############################################################################
# What gets noticed                                                          #
##############################################################################
# An edit to a meson.build is the build rule's to notice, not the
# configure rule's: build.ninja re-runs meson itself when one of its
# inputs moves, so starting over would be a rebuild bought for nothing.
sleep 1
echo "# edited" >> sub/meson.build
make $MAKE_ARGS > edited.out
cat edited.out
test "$(grep -c '^meson setup' $MESON_FAKE_LOG)" = 1
test "$(grep -c '^ninja -C obj/sub/build$' $MESON_FAKE_LOG)" = 2

# A build-side option is one more ninja in a tree that is already set
# up, not a setup.
sleep 1
echo "CONFIGUREOPTS += --target extra thing" >> Configfile
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS > target.out
cat target.out
test "$(grep -c '^meson setup' $MESON_FAKE_LOG)" = 1
grep -q "^target=\[extra thing\] jobs=\[\]$" obj/sub/build/ninja-ran.txt

# A configure-side option starts over, and takes the old prefix with
# it before the install puts back what this configuration installs.
sleep 1
echo "only-the-old-configuration" > obj/sub/prefix/stale
echo "CONFIGUREOPTS += --define tests=false" >> Configfile
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS > reconfigure.out
cat reconfigure.out
test "$(grep -c '^meson setup' $MESON_FAKE_LOG)" = 2
grep -q "'-Dtests=false'" Makefile
test ! -e obj/sub/prefix/stale
test -f obj/sub/prefix/bin/tool

# A "make clean" takes the stamp and the default prefix and leaves the
# build directory, which is the tree's to decide about.
make $MAKE_ARGS clean > clean.out
test ! -e obj/sub/build-stamp
test ! -e obj/sub/prefix
test -f obj/sub/build/build.ninja

##############################################################################
# --jobs                                                                     #
##############################################################################
mkdir -p $top/jobs
fake_tree $top/jobs/sub
cat >$top/jobs/Configfile <<'EOF'
BUILD_SYSTEMS += meson
SUBPROJECTS   += sub
CONFIGUREOPTS += --jobs 4
EOF
(cd $top/jobs && $PTEST_BINARY $PCONFIGURE_ARGS && make $MAKE_ARGS)
grep -q "^target=\[\] jobs=\[4\]$" $top/jobs/obj/sub/build/ninja-ran.txt

mkdir -p $top/jobs-word
fake_tree $top/jobs-word/sub
cat >$top/jobs-word/Configfile <<'EOF'
BUILD_SYSTEMS += meson
SUBPROJECTS   += sub
CONFIGUREOPTS += --jobs lots
EOF
if (cd $top/jobs-word && $PTEST_BINARY $PCONFIGURE_ARGS) > jobs-word.out 2>&1
then
    exit 1
fi
cat jobs-word.out
grep -q "'--jobs lots' isn't a number of jobs" jobs-word.out

##############################################################################
# --no-install                                                               #
##############################################################################
# A SUBPROJECT_TARGETS is named from the build directory, and there is
# no prefix for a configure or a clean to take.  The setup is still told
# one, since meson bakes a prefix into what it builds whether or not
# anything is ever installed there, and the alternative is /usr/local.
mkdir -p $top/no-install
fake_tree $top/no-install/sub
cat >$top/no-install/Configfile <<'EOF'
BUILD_SYSTEMS += meson
SUBPROJECTS   += sub
CONFIGUREOPTS += --no-install
SUBPROJECT_TARGETS += built.txt
EOF
(cd $top/no-install && $PTEST_BINARY $PCONFIGURE_ARGS && make $MAKE_ARGS)
test -f $top/no-install/obj/sub/build/built.txt
test ! -e $top/no-install/obj/sub/prefix
grep -q -- "'--prefix=\$(abspath obj/sub/prefix)'" $top/no-install/Makefile
if grep -q "rm -fr obj/sub/prefix\|'install'" $top/no-install/Makefile
then
    exit 1
fi

##############################################################################
# A shared prefix                                                            #
##############################################################################
# A --prefix is a directory somebody wrote down and peers may install
# into, so neither a configure nor a clean removes it.
mkdir -p $top/shared
fake_tree $top/shared/sub
cat >$top/shared/Configfile <<'EOF'
BUILD_SYSTEMS += meson
SUBPROJECTS   += sub
CONFIGUREOPTS += --prefix obj/toolchain
SUBPROJECT_TARGETS += bin/tool
EOF
(cd $top/shared && $PTEST_BINARY $PCONFIGURE_ARGS && make $MAKE_ARGS)
test -f $top/shared/obj/toolchain/bin/tool
grep -q -- "'--prefix=\$(abspath obj/toolchain)'" $top/shared/Makefile
if grep -q "rm -fr obj/toolchain" $top/shared/Makefile
then
    exit 1
fi
(cd $top/shared && make $MAKE_ARGS clean)
test -f $top/shared/obj/toolchain/bin/tool

##############################################################################
# A tree that sets itself up                                                 #
##############################################################################
# QEMU's meson.build reads a file only its own configure writes, so the
# configure is what has to run, from inside the build directory, and it
# runs "meson setup" itself.  This one writes down where it ran and
# what it was handed, then leaves the build directory the fake ninja
# wants -- and calls the fake meson not at all, which is how the log
# tells "the script set it up" from "pconfigure ran meson anyway".
mkdir -p $top/script
fake_tree $top/script/sub
cat >$top/script/sub/configure <<'EOF'
#!/bin/sh
set -e
pwd > ran-in.txt
for arg in "$@"
do
    echo "arg=[$arg]"
done > args.txt
echo "MY_ENV=$MY_ENV" > env.txt
for arg in "$@"
do
    case "$arg" in
    --prefix=*) echo "${arg#--prefix=}" > prefix.txt;;
    esac
done
echo "# from configure" > build.ninja
EOF
chmod +x $top/script/sub/configure

cat >$top/script/Configfile <<'EOF'
BUILD_SYSTEMS += meson
SUBPROJECTS   += sub
CONFIGUREOPTS += --setup-script configure
CONFIGUREOPTS += --build-type release
CONFIGUREOPTS += --define targets=one, two
CONFIGUREOPTS += --configure-arg --target-list=riscv64-softmmu
CONFIGUREOPTS += --env MY_ENV=one two
SUBPROJECT_TARGETS += bin/tool
EOF

: > $MESON_FAKE_LOG
(cd $top/script && $PTEST_BINARY $PCONFIGURE_ARGS)
cat $top/script/Makefile

awk '/^\t/ { if (p) print; next } { p = 0 } /^obj\/sub\/build\/build.ninja:/ { p = 1 }' $top/script/Makefile > script.rule
cat script.rule
grep -q "cd obj/sub/build && MY_ENV='one two' \$(abspath sub)/configure '--prefix=" script.rule
if grep -q "meson setup" script.rule
then
    exit 1
fi

(cd $top/script && make $MAKE_ARGS)
if grep -q "^meson" $MESON_FAKE_LOG
then
    exit 1
fi

# Run from inside the build directory, with everything a "meson setup"
# would have had bar the two directories, each still one argument.
build=$top/script/obj/sub/build
test "$(cat $build/ran-in.txt)" = "$(cd $build && pwd -P)" \
    || test "$(cat $build/ran-in.txt)" = "$(cd $build && pwd)"
cat $build/args.txt
grep -q "^arg=\[--prefix=/.*/script/obj/sub/prefix\]$" $build/args.txt
grep -q "^arg=\[-Dbuildtype=release\]$" $build/args.txt
grep -q "^arg=\[-Dtargets=one, two\]$" $build/args.txt
grep -q "^arg=\[--target-list=riscv64-softmmu\]$" $build/args.txt
test "$(wc -l < $build/args.txt)" -eq 4
grep -q "^MY_ENV=one two$" $build/env.txt

# And from there on it's ninja's, as it is for any other tree.
test -f $top/script/obj/sub/prefix/bin/tool
test -f $top/script/obj/sub/build-stamp

##############################################################################
# Refusals                                                                   #
##############################################################################
# Each takes a Configfile line and the text the refusal has to contain.
refused()
{
    mkdir -p $top/$1
    fake_tree $top/$1/sub

    {
        echo "BUILD_SYSTEMS += meson"
        echo "SUBPROJECTS   += sub"
        echo "$2"
    } > $top/$1/Configfile
    cat $top/$1/Configfile

    if (cd $top/$1 && $PTEST_BINARY $PCONFIGURE_ARGS) > $top/$1.out 2>&1
    then
        exit 1
    fi
    cat $top/$1.out

    grep -q -- "$3" $top/$1.out

    # A configure that stopped wrote no Makefile.
    test ! -e $top/$1/Makefile
}

# There is no make for a variable to go on the command line of.
refused makeops "MAKEOPS += CC=clang" \
    "MAKEOPS doesn't apply to a meson subproject"
grep -q "write 'CONFIGUREOPTS += --define NAME=VALUE'" $top/makeops.out

refused no-value "CONFIGUREOPTS += --define tests" \
    "'--define tests' has no value"

refused unknown "CONFIGUREOPTS += --generator Ninja" \
    "unknown CONFIGUREOPTS '--generator Ninja'"

# Every spelling of a second answer to where the tree installs: as a
# build option, as meson's own option, as the abbreviation argparse
# reads as that option, as a "-D" on the command line, and as the
# DESTDIR the install reads out of the environment.
for spelling in \
    "define:--define prefix=/opt/x" \
    "arg-long:--configure-arg --prefix=/opt/x" \
    "arg-abbrev:--configure-arg --prefi=/opt/x" \
    "arg-d:--configure-arg -Dprefix=/opt/x" \
    "env-destdir:--env DESTDIR=/opt/x"
do
    refused "answer-${spelling%%:*}" "CONFIGUREOPTS += ${spelling#*:}" \
        "write '--prefix DIR' instead"
done

# A setup script is a file inside the tree, spelled so it can be pasted
# into a recipe as a bare word.
refused script-up "CONFIGUREOPTS += --setup-script ../configure" \
    "isn't a file inside the tree"
refused script-absolute "CONFIGUREOPTS += --setup-script /bin/sh" \
    "isn't a file inside the tree"
refused script-down-up "CONFIGUREOPTS += --setup-script src/../../x" \
    "isn't a file inside the tree"
refused script-space "CONFIGUREOPTS += --setup-script con figure" \
    "isn't a file inside the tree"
refused script-dollar "CONFIGUREOPTS += --setup-script \$(HOME)/x" \
    "isn't a file inside the tree"
refused script-missing "CONFIGUREOPTS += --setup-script configure" \
    "'--setup-script configure' isn't a program in sub"

# And it gets the same second-answer refusals meson does, since it is
# handed the same words.
refused script-prefix "CONFIGUREOPTS += --setup-script configure
CONFIGUREOPTS += --configure-arg --prefix=/usr/local" \
    "write '--prefix DIR' instead"

# A directory option is read under the prefix when it is relative, so
# that's allowed; an absolute one moves part of the install out from
# under it, so that isn't.
refused absolute-bindir "CONFIGUREOPTS += --define bindir=/usr/bin" \
    "bindir"

mkdir -p $top/relative-libdir
fake_tree $top/relative-libdir/sub
cat >$top/relative-libdir/Configfile <<'EOF'
BUILD_SYSTEMS += meson
SUBPROJECTS   += sub
CONFIGUREOPTS += --define libdir=lib64
EOF
(cd $top/relative-libdir && $PTEST_BINARY $PCONFIGURE_ARGS)
grep -q -- "'-Dlibdir=lib64'" $top/relative-libdir/Makefile

exit 0
