#include "harness_start.bash"

top="$tempdir"

# The same directory, spelled the way make spells it.  "$(abspath)"
# builds its answer out of make's own idea of where it is, which comes
# from getcwd() and so has every symlink already resolved -- while
# "mktemp -t" on a Mac hands back a path that goes through one.  Every
# comparison below between a path this test wrote down and a path
# pconfigure handed cargo has to be made in the resolved spelling or
# it is a comparison of two names for one directory.
abs="$(pwd -P)"

##############################################################################
# The program a Rust crate is built with                                     #
##############################################################################
# Running a vendored crate means running cargo, which is not a thing
# this machine can be relied on to have -- and even where it is there,
# a real cargo wants a network, a registry and a toolchain, none of
# which a test should be reaching for.  This stands in for it: a
# program called "cargo" that writes down how it was called and then
# does the smallest thing that keeps the build moving.
#
# What's under test is the command line pconfigure writes, the
# environment it writes it in and the directory it expects the answer
# to land in -- not what cargo does once it has been run.  So a fake
# that lays its output out the way cargo's documentation says cargo
# lays it out is as good as the real thing would be here, and it has
# the considerable advantage of behaving the same way on every
# machine.
#
# It refuses what it must be given, which is the part that makes it an
# assertion rather than decoration: a fake that tolerates anything
# proves nothing about what it was handed.  A build without an
# absolute --target-dir would be a crate writing into somebody else's
# checkout, and a build without a --manifest-path would be cargo
# looking upwards for a crate until it found one.  A run from
# anywhere but inside the crate is one that never read the crate's
# own ".cargo/config.toml".  An install handed a "--package" is a
# command line the real cargo rejects outright, and one that has to
# overwrite what it installed last time without a "--force" is a
# build that stops dead the second time it runs.
#
# And it refuses to invent: an install copies what a build left
# behind rather than making it, so an install and a build that
# disagree about which directory they mean fail here rather than
# quietly producing a program out of nothing.
#
# It lives beside the fixture rather than inside it: anything under
# "sub" is something pconfigure chases as a dependency and something
# the "nothing was written in the tree" assertions have to reason
# about.
fakedir="$top/fake"
mkdir -p $fakedir

cat >$fakedir/cargo <<EOF
#!/bin/sh
set -e

fakedir="$fakedir"
EOF

# The quoted heredoc is what keeps the shell writing this file from
# reading the "\$@" that the shell running it is supposed to read.
cat >>$fakedir/cargo <<'EOF'
subcommand="$1"
shift

case "$subcommand" in
build|install) ;;
*)
    echo "cargo: there is no '$subcommand' subcommand" 1>&2
    exit 1
    ;;
esac

manifest=
path=
target_dir=
root=
profile=
triple=
bins=
no_track=
force=
previous=
for argument in "$@"
do
    # "cargo install" takes a different set of arguments than "cargo
    # build" does, and the one that gets written by accident is
    # "--package": install hasn't got it at all, it installs whatever
    # its "--path" names.  A fake that ignored every flag it doesn't
    # parse would accept a command line the real cargo rejects, which
    # is the whole of what this test is for.
    #
    # Nothing pconfigure writes reaches this today, and that is on
    # purpose twice over: a "--package" together with an "--install"
    # is refused at configure time, and where there is no install the
    # "--package" only ever goes on the build line.  It is kept as
    # the net under both of those, since either one could be changed
    # by somebody who had only the other in mind -- and it is pulled
    # on directly at the bottom of this test, because a net nobody
    # ever tests is a net nobody knows is still tied.
    if [ "$subcommand" = "install" ]
    then
        case "$argument" in
        --package|--package=*|-p)
            echo "cargo: unexpected argument '$argument' found" 1>&2
            exit 1
            ;;
        esac
    fi

    case "$previous" in
    --manifest-path) manifest="$argument" ;;
    --path)          path="$argument" ;;
    --target-dir)    target_dir="$argument" ;;
    --root)          root="$argument" ;;
    --profile)       profile="$argument" ;;
    --target)        triple="$argument" ;;
    --bin)           bins="$bins $argument" ;;
    esac

    if [ "$argument" = "--no-track" ]
    then
        no_track=yes
    fi

    if [ "$argument" = "--force" ]
    then
        force=yes
    fi

    previous="$argument"
done

# Four of these cargo reads off its environment when the command line
# didn't say, and this reads them the same way round: the command line
# first, the variable second.  That is not decoration.  It is the
# whole of why pconfigure refuses those four names in an "--env" --
# and a fake that ignored them would go on saying a build landed where
# the command line said it would while a real cargo put it somewhere
# else entirely, which is the one kind of wrong an instrument must not
# be.
#
# Three of the four are shadowed here exactly as cargo shadows them,
# since the command line is read first.  The one that isn't is
# CARGO_BUILD_TARGET: nothing writes a "--target" unless a
# CONFIGUREOPTS asked for one, so this is what a build with no
# "--target" reads, and it moves every program down into a directory
# named after the triple.
if [ -z "$target_dir" ]
then
    target_dir="${CARGO_TARGET_DIR:-$CARGO_BUILD_TARGET_DIR}"
fi

if [ -z "$triple" ]
then
    triple="$CARGO_BUILD_TARGET"
fi

if [ -z "$root" ]
then
    root="$CARGO_INSTALL_ROOT"
fi

# Where cargo is told to write is the whole of what keeps a vendored
# crate out of the tree it was vendored from, so a cargo that wasn't
# told, or was told relatively, is one this test wants to hear about.
if [ -z "$target_dir" ]
then
    echo "cargo: run without a --target-dir" 1>&2
    exit 1
fi

case "$target_dir" in
/*) ;;
*)
    echo "cargo: '--target-dir $target_dir' isn't an absolute path" 1>&2
    exit 1
    ;;
esac

if [ "$subcommand" = "build" ]
then
    if [ -z "$manifest" ]
    then
        echo "cargo: run without a --manifest-path" 1>&2
        exit 1
    fi

    if [ ! -f "$manifest" ]
    then
        echo "cargo: '$manifest' isn't a manifest" 1>&2
        exit 1
    fi

    crate="$manifest"
else
    if [ -z "$root" ]
    then
        echo "cargo: install without a --root" 1>&2
        exit 1
    fi

    if [ -z "$no_track" ]
    then
        echo "cargo: install without a --no-track" 1>&2
        exit 1
    fi

    if [ ! -f "$path/Cargo.toml" ]
    then
        echo "cargo: '$path' isn't a crate" 1>&2
        exit 1
    fi

    crate="$path/Cargo.toml"
fi

# And where it was run from, which a --manifest-path is not a
# substitute for: cargo reads ".cargo/config.toml" from the current
# directory upward and never from beside the manifest, so a cargo run
# from the project root builds a vendored crate with whatever
# configuration the project happens to have rather than with the
# crate's own.
here="$(pwd -P)"
crate_dir="$(cd "$(dirname "$crate")" && pwd -P)"
if [ "$here" != "$crate_dir" ]
then
    echo "cargo: run in '$here' rather than in '$crate_dir'" 1>&2
    exit 1
fi

name=$(sed -n 's/^name = "\(.*\)"$/\1/p' "$crate")

# One witness per crate per subcommand, rather than one for all of
# them: a project with two crates in it runs this twice, and a witness
# they shared would only ever say what the second one was handed.
#
# One line per argument, so that an argument with a space in it can be
# told from two arguments.
printf '%s\n' "$@" > $fakedir/$name.$subcommand.args

# And the environment separately, since a variable that was never set
# and a variable set to nothing look identical from out here unless
# the program that saw it says which one it was.
{
    echo "cwd=$here"
    echo "RUSTFLAGS=$RUSTFLAGS"
    echo "CARGO_TARGET_DIR=$CARGO_TARGET_DIR"
    echo "CARGO_BUILD_TARGET_DIR=$CARGO_BUILD_TARGET_DIR"
    echo "CARGO_BUILD_TARGET=$CARGO_BUILD_TARGET"
    echo "CARGO_INSTALL_ROOT=$CARGO_INSTALL_ROOT"
} > $fakedir/$name.$subcommand.env

# Cargo's own output layout, written out here a second time from its
# documentation rather than read back off pconfigure: the four
# profiles it ships share two directories between them, a profile
# somebody wrote themselves gets a directory of its own name, and an
# explicit --target puts a directory in front of all of that.
#
# The two subcommands do not default to the same profile, which is the
# trap this fake exists to spring: "cargo build" with nothing said
# builds "dev" and "cargo install" with nothing said builds "release".
# That asymmetry is why "cargo install" has a "--debug" flag at all,
# and it is why a recipe that tells neither of them which profile it
# means builds the crate twice and installs the copy nothing else is
# looking at.
case "$profile" in
"")
    if [ "$subcommand" = "install" ]
    then
        directory=release
    else
        directory=debug
    fi
    ;;
dev|test)      directory=debug ;;
release|bench) directory=release ;;
*)             directory="$profile" ;;
esac

if [ -n "$triple" ]
then
    directory="$triple/$directory"
fi

# Whichever programs were asked for, or the crate's own name when
# nobody said.
if [ -z "$bins" ]
then
    bins="$name"
fi

if [ "$subcommand" = "build" ]
then
    mkdir -p "$target_dir/$directory"
    for program in $bins
    do
        echo "built $program" > "$target_dir/$directory/$program"
        echo "RUSTFLAGS=$RUSTFLAGS" >> "$target_dir/$directory/$program"
    done

    exit 0
fi

# An install moves what a build already made, and this one refuses to
# invent it: a fake that created the program it was asked to install
# would install happily from a directory the build never wrote to,
# which is exactly what a profile the install disagrees with looks
# like from out here.
mkdir -p "$root/bin"
for program in $bins
do
    if [ ! -f "$target_dir/$directory/$program" ]
    then
        echo "cargo: no '$program' in '$target_dir/$directory'" 1>&2
        echo "cargo: nothing built it there" 1>&2
        exit 1
    fi

    # The real cargo will not overwrite a program it has already
    # installed, and with --no-track the file being there is the whole
    # of what it looks at.  This rule's recipe runs again every time
    # the crate does, so a second install is the normal case rather
    # than a mistake -- and without --force it would take the build
    # down with it.
    if [ -f "$root/bin/$program" ] && [ -z "$force" ]
    then
        echo "cargo: binary \`$program' already exists in destination" 1>&2
        echo "Add --force to overwrite" 1>&2
        exit 1
    fi

    cp "$target_dir/$directory/$program" "$root/bin/$program"
done
EOF
chmod +x $fakedir/cargo

export PATH="$fakedir:$PATH"

##############################################################################
# And the same program, pinned to a path instead of found on the PATH        #
##############################################################################
# A project that pins its toolchain writes "--cargo tools/cargo",
# which is a path rather than a program name and so is the case where
# it matters that the recipe runs from inside the crate: read from
# down there, "tools/cargo" is a file in somebody else's checkout.
#
# This wrapper is what proves the path was resolved rather than
# handed over as written.  It runs nothing of its own -- the fake
# above is still what cargo does here -- but it writes down where it
# was run from before it does, so the assertions below can say both
# that it ran at all and that it ran from inside the crate, which is
# exactly the pair of facts the bug this guards against separates.
#
# It lives beside the project's Configfile rather than under a crate,
# because that is where a pinned toolchain lives: it belongs to the
# project that vendored the tree, not to the tree.
mkdir -p $top/tools
cat >$top/tools/cargo <<EOF
#!/bin/sh
pwd -P >> "$top/tools/used"
exec "$fakedir/cargo" "\$@"
EOF
chmod +x $top/tools/cargo

##############################################################################
# The crates                                                                 #
##############################################################################
mkdir -p sub/src sub2/src sub3/src

# A crate is a Cargo.toml and nothing else has to be said: no
# Configfile goes in here, because a vendored tree is somebody else's
# and shouldn't have to carry a file that says it's ours.
cat >sub/Cargo.toml <<'EOF'
[package]
name = "hello"
version = "0.1.0"
EOF

cat >sub/Cargo.lock <<'EOF'
version = 3
EOF

cat >sub/src/main.rs <<'EOF'
fn main() { println!("hello"); }
EOF

# The file a vendored crate pins its rustflags, its linker and its
# vendored registry in.  It is the one dot-directory the walk goes
# into, and it has to be: cargo reads it from the directory it is run
# in rather than from beside the manifest, so a crate that has one is
# a crate cargo has to be run inside -- and editing it changes what
# the build does as surely as editing a Cargo.toml would.
mkdir -p sub/.cargo
cat >sub/.cargo/config.toml <<'EOF'
[build]
rustflags = ["--cfg", "vendored"]
EOF

# And the bookkeeping that is still skipped, which is what makes the
# line above an exception rather than the end of the rule: a ".git" is
# bigger than the crate it holds and nothing in it is a source.
mkdir -p sub/.git
cat >sub/.git/config.toml <<'EOF'
this = "not a source"
EOF

# A crate cargo has been run in by hand before, which is the normal
# state of a checkout somebody has been working in.  Its "target" is
# cargo's own output and holds more files than the crate does, so a
# walk that went in there would put the build's product in the list of
# things the build reads.
mkdir -p sub/target/debug
echo "stale" > sub/target/debug/hello
cat >sub/target/scratch.rs <<'EOF'
fn stale(void) {}
EOF

cat >sub2/Cargo.toml <<'EOF'
[package]
name = "world"
version = "0.1.0"
EOF

cat >sub2/src/main.rs <<'EOF'
fn main() { println!("world"); }
EOF

# Cargo's older spelling of the file "sub" has as a ".cargo/config.toml":
# a ".cargo/config" with no extension at all.  It is deprecated rather
# than gone -- cargo still reads it, and a crate that was vendored
# before the rename still has one -- and it decides everything the
# newer spelling decides.
#
# It goes in a second crate rather than beside the first one's,
# because the two spellings together is a state cargo warns about and
# nobody's tree is really in.  Which makes this the crate that says
# the walk's ".cargo" exception is worth having on its own: the
# directory is let in, and then the file in it has to survive the
# extension filter at the end of the walk to be worth anything.
mkdir -p sub2/.cargo
cat >sub2/.cargo/config <<'EOF'
[build]
rustflags = ["--cfg", "legacy"]
EOF

# And a crate that installs without saying which profile it wants,
# which is the only way to find out that the two halves of the recipe
# do not default to the same one: "cargo build" with nothing said
# builds "dev" and "cargo install" with nothing said builds "release".
cat >sub3/Cargo.toml <<'EOF'
[package]
name = "tool"
version = "0.1.0"
EOF

cat >sub3/src/main.rs <<'EOF'
fn main() { println!("tool"); }
EOF

##############################################################################
# The project that vendors them                                              #
##############################################################################
# Three crates, because no one of them can say everything worth
# knowing about this build system's output layout: "sub" is built for
# this machine and named out of the build directory, "sub2" is built
# for another one -- which puts a directory nobody wrote in front of
# the profile -- and installed into a directory of the project's own,
# and "sub3" installs into that same directory without naming a
# profile at all.
#
# That last one is not a spare: an install that says nothing about the
# profile is the case where "cargo build" and "cargo install" disagree
# about which directory they mean, and a crate that names its profile
# can't tell anybody about it.  The shared install root is the normal
# case too -- a project vendors several trees and wants their programs
# in one "bin".
#
# "sub3" is also the one that pins the program it is built with,
# which is the other thing only a crate that installs can say
# everything about: a "--cargo" that names a path has to survive the
# "cd" into the crate on both halves of the recipe, and the install
# half is the half that would be found broken last.
#
# The options that decide where a program lands are written directly
# under the SUBPROJECTS, above the SUBPROJECT_TARGETS that names one,
# because a SUBPROJECT_TARGETS is resolved where it's written.
cat >Configfile <<'EOF'
BUILD_SYSTEMS += cargo

SUBPROJECTS   += sub
CONFIGUREOPTS += --release
CONFIGUREOPTS += --locked
CONFIGUREOPTS += --offline
CONFIGUREOPTS += --jobs 3
CONFIGUREOPTS += --features one two
CONFIGUREOPTS += --env RUSTFLAGS=-C target-cpu=native
CONFIGUREOPTS += --arg --message-format short
SUBPROJECT_TARGETS += hello

SUBPROJECTS   += sub2
CONFIGUREOPTS += --profile dev
CONFIGUREOPTS += --target fake-unknown-none
CONFIGUREOPTS += --bin world
CONFIGUREOPTS += --install obj/stage
CONFIGUREOPTS += --depend sub
SUBPROJECT_TARGETS += world

SUBPROJECTS   += sub3
CONFIGUREOPTS += --cargo tools/cargo
CONFIGUREOPTS += --install obj/stage
SUBPROJECT_TARGETS += tool
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

##############################################################################
# What configure time wrote, and what it did not                             #
##############################################################################
# Nothing at all was written inside any of the crates.  Cargo's whole
# habit is to make a "target" beside the Cargo.toml, and the
# "--target-dir" this build system insists on deciding for itself is
# what stops it -- but that's a make-time thing, and at configure time
# the trees are still exactly as they were found.
test ! -e sub/target/release
test ! -e sub2/target
test ! -e sub3/target

# The one thing configure time writes on this side of the fence is the
# list of options the crate is about to be built with, which has to
# exist before make runs because make is what compares it against the
# last one.  Cargo's target directory is still make's to create, and
# so is the install root.
test -f obj/sub/configure-opts
test -f obj/sub2/configure-opts
test ! -e obj/sub/target
test ! -e obj/sub/build-stamp
test ! -e obj/stage

# One raw CONFIGUREOPTS line per line, in the order they were written,
# and nothing else: everything that reaches cargo arrived as an
# option, there are no MAKEOPS because there is no make, and nothing
# derived goes in -- a derived path is spelled differently by a run at
# the top of the tree and a run inside the subproject, and the two
# would undo each other's file forever.
cat obj/sub/configure-opts
cat >expected-opts <<'EOF'
--release
--locked
--offline
--jobs 3
--features one two
--env RUSTFLAGS=-C target-cpu=native
--arg --message-format short
EOF
diff expected-opts obj/sub/configure-opts

cat obj/sub2/configure-opts
cat >expected-opts2 <<'EOF'
--profile dev
--target fake-unknown-none
--bin world
--install obj/stage
--depend sub
EOF
diff expected-opts2 obj/sub2/configure-opts

##############################################################################
# The rules                                                                  #
##############################################################################
# One rule per crate, because cargo is one command: it reads the
# manifest, works out what has to happen and does it, so there is no
# moment in the middle where the crate is configured and not yet built
# for a second rule to hang off.
grep -q "^obj/sub/build-stamp:" Makefile
grep -q "^all: obj/sub/build-stamp$" Makefile
grep -q "^obj/sub2/build-stamp:" Makefile

# There is no configure rule, and the positive twin of that is the
# build rule right above: a build system with two rules would have
# written a stamp and something else beside it.
if grep -q "^obj/sub/config" Makefile
then
    exit 1
fi

# The manifest and the target directory reach cargo absolutely, both
# for the same reason: cargo writes the paths it was handed into the
# fingerprints it keeps in its target directory, so a build run from
# the top of the tree and a build run from inside a subproject have to
# hand it the same two strings or the second decides everything is
# stale.
# And they reach it as one word each, quoted the way every path this
# recipe writes is: the directory a SUBPROJECTS named is a directory
# somebody chose the name of, and the object directory underneath is
# named after it, so an apostrophe anywhere in that name is in both of
# these.  The quotes go round the whole "$(abspath)" rather than round
# the path inside it, because it is the recipe a shell reads.
grep -q -- "--manifest-path '\$(abspath sub/Cargo.toml)'" Makefile
grep -q -- "--target-dir '\$(abspath obj/sub/target)'" Makefile

# One --arg is one argument to cargo however many spaces are in it,
# and an environment variable's value is one word for the same reason:
# an unquoted "RUSTFLAGS=-C target-cpu=native" is a RUSTFLAGS worth
# "-C" followed by a program called "target-cpu=native".
grep -q -- "'--message-format short'" Makefile
grep -q -- "RUSTFLAGS='-C target-cpu=native' 'cargo' build" Makefile

# And cargo is run from inside the crate rather than pointed at it
# from outside, because a --manifest-path doesn't move where cargo
# looks for ".cargo/config.toml": that search starts at the current
# directory, so a cargo run from up here reads the vendoring project's
# configuration instead of the vendored crate's.
grep -q "cd 'sub' && .*'cargo' build" Makefile
grep -q "cd 'sub2' && .*'cargo' install" Makefile

# Which is what a "--cargo" that names a path has to be written
# around: "tools/cargo" was said by the project that vendored the
# tree, and the recipe it lands in has already gone into the crate, so
# it is resolved against the project and made absolute out here.  Both
# halves of the recipe, since the install runs from in there too.
grep -q -- "cd 'sub3' && '\$(abspath tools/cargo)' build" Makefile
grep -q -- "cd 'sub3' && '\$(abspath tools/cargo)' install" Makefile

# And the spelling that would have been written by handing the option
# over as it arrived, which make would run inside the crate: either
# "not found", or -- in a tree that happens to have a "tools" of its
# own -- somebody else's program.
if grep -q -- "cd 'sub3' && 'tools/cargo'" Makefile
then
    exit 1
fi

# The crate's own sources are what make looks at to decide whether to
# run cargo at all, through a $(wildcard) so that a file which goes
# away stops being named rather than stopping make dead.
grep -q "sub/src/main.rs" Makefile
grep -q "sub/Cargo.lock" Makefile

# Including the one dot-file that is a source: everything else
# starting with a '.' is somebody's bookkeeping, but this one decides
# what cargo does.
grep -q "sub/.cargo/config.toml" Makefile

# And its older spelling, in the crate that has that one instead.
# Letting the walk into ".cargo" buys nothing unless what is in there
# comes out the far end of the extension filter, and this file hasn't
# got an extension: a crate configured out of a ".cargo/config" would
# otherwise have that file editable without anything running cargo
# again, which is the exact failure the exception exists to prevent.
#
# Anchored on what follows the name so that it can't be satisfied by
# the "config.toml" in the other crate, or by a "config.toml" that
# turned up in this one.
grep -qE "sub2/\.cargo/config[ )]" Makefile

# And nothing else that starts with one.  A walk that went into ".git"
# would name more files than the crate has and rebuild the tree every
# time anybody committed anything.
if grep -q "sub/.git" Makefile
then
    exit 1
fi

# And cargo's own output directory is not one of them.  A crate
# somebody has run cargo in by hand has a "target" full of files the
# build produces rather than reads, and naming those would give make a
# reason to rebuild after every build, forever.
if grep -q "sub/target/scratch.rs" Makefile
then
    exit 1
fi

# A --depend on another vendored tree waits for that tree to have been
# built rather than for its directory to change, which is the only one
# of the two anybody means.
grep -q "^obj/sub2/build-stamp:.*obj/sub/build-stamp" Makefile

# Where a program lands is cargo's layout rather than a choice, and a
# SUBPROJECT_TARGETS is named relative to it: "world" rather than
# "fake-unknown-none/debug/world", so the Configfile says what the
# crate produces instead of where cargo happens to put it.
grep -q "^obj/sub/target/release/hello:" Makefile
grep -q "^obj/sub2/target/fake-unknown-none/debug/world:" Makefile

# And a crate that named no profile at all builds into "debug", which
# is cargo's build-side default said in cargo's own spelling.
grep -q "^obj/sub3/target/debug/tool:" Makefile

##############################################################################
# The build                                                                  #
##############################################################################
make $MAKE_ARGS > first.out
cat first.out

tab="$(printf '\t')"
grep -q "CARGO${tab}sub$" first.out
grep -q "CARGO${tab}sub2$" first.out
grep -q "CARGO${tab}sub3$" first.out

# What cargo was actually handed, read back out of the witness the
# fake wrote.  One line per argument is what makes this an assertion
# about quoting: "--message-format short" on one line is one argument,
# and on two lines it would be two.
cat $fakedir/hello.build.args
grep -q -- "^--message-format short$" $fakedir/hello.build.args
grep -q -- "^--locked$" $fakedir/hello.build.args
grep -q -- "^--offline$" $fakedir/hello.build.args

# The whole command line rather than the interesting parts of it,
# because the parts nobody asserted on are the parts that go wrong: a
# flag that shouldn't be there passes every grep written about the
# flags that should.
#
# The temporary directory this runs in turns up in the absolute paths,
# and on a Mac it has two spellings -- the one mktemp handed back and
# the one its symlinks resolve to.  Which of them make's "$(abspath)"
# built its answer out of is make's business rather than this test's,
# so both are rewritten to the same word and what is left is what is
# actually being asserted.
sed -e "s|^$abs/|TOP/|" -e "s|^$top/|TOP/|" \
    $fakedir/hello.build.args > build-args
cat >expected-build-args <<'EOF'
--manifest-path
TOP/sub/Cargo.toml
--target-dir
TOP/obj/sub/target
--profile
release
--features
one two
--locked
--offline
--jobs
3
--message-format short
EOF
diff expected-build-args build-args

# And the environment separately, which is a different thing from an
# argument: a variable is only true for the run that saw it.
cat $fakedir/hello.build.env
grep -q "^RUSTFLAGS=-C target-cpu=native$" $fakedir/hello.build.env

# And none of the four variables that would have moved where any of
# this landed was set, which is the positive half of the refusals
# further down: the witness says they arrived empty rather than merely
# that the program turned up where it was expected.
grep -q "^CARGO_TARGET_DIR=$" $fakedir/hello.build.env
grep -q "^CARGO_BUILD_TARGET_DIR=$" $fakedir/hello.build.env
grep -q "^CARGO_BUILD_TARGET=$" $fakedir/hello.build.env
grep -q "^CARGO_INSTALL_ROOT=$" $fakedir/hello.build.env

# Including the directory cargo ran in, which is the crate rather than
# the project that vendored it: ".cargo/config.toml" is found by
# walking up from there, so a cargo run from anywhere else is a cargo
# that never read the crate's own configuration.
test "$(grep '^cwd=' $fakedir/hello.build.env)" = "cwd=$abs/sub"
test "$(grep '^cwd=' $fakedir/world.build.env)" = "cwd=$abs/sub2"
test "$(grep '^cwd=' $fakedir/world.install.env)" = "cwd=$abs/sub2"

# And the install's command line, which is the half of this that used
# to go unread.  Every flag on it is one this test named on purpose:
# "--force" because this recipe reruns whenever the crate does and
# cargo refuses to overwrite what it installed last time, "--profile
# dev" because "cargo install" defaults to "release" where "cargo
# build" defaults to "dev" and the two halves have to mean the same
# directory, and no "--package" at all because "cargo install" hasn't
# got one.
cat $fakedir/world.install.args
sed -e "s|^$abs/|TOP/|" -e "s|^$top/|TOP/|" \
    $fakedir/world.install.args > install-args
cat >expected-install-args <<'EOF'
--path
TOP/sub2
--root
TOP/obj/stage
--target-dir
TOP/obj/sub2/target
--no-track
--force
--profile
dev
--target
fake-unknown-none
--bin
world
EOF
diff expected-install-args install-args

# And the crate that named no profile, which is where the two
# defaults part company: the build says nothing and gets "dev", so the
# install has to be told "dev" outright or it would build "release"
# into a directory nothing else here ever looks in -- twice, and the
# second time is the copy that reaches the install root.
cat $fakedir/tool.build.args
sed -e "s|^$abs/|TOP/|" -e "s|^$top/|TOP/|" \
    $fakedir/tool.build.args > build-args3
cat >expected-build-args3 <<'EOF'
--manifest-path
TOP/sub3/Cargo.toml
--target-dir
TOP/obj/sub3/target
EOF
diff expected-build-args3 build-args3

cat $fakedir/tool.install.args
sed -e "s|^$abs/|TOP/|" -e "s|^$top/|TOP/|" \
    $fakedir/tool.install.args > install-args3
cat >expected-install-args3 <<'EOF'
--path
TOP/sub3
--root
TOP/obj/stage
--target-dir
TOP/obj/sub3/target
--no-track
--force
--profile
dev
EOF
diff expected-install-args3 install-args3

# And that crate was built by the cargo it pinned rather than by the
# one on the PATH, which is the positive half of the Makefile
# assertion above: the wrapper writes down every directory it was run
# from, and both of the directories it was run from are the crate.
#
# The negative half is make itself.  A "tools/cargo" handed over as
# written would have been looked for under "sub3", where there is no
# such file, and the make that ran above would have stopped -- so
# there is no spelling of this bug that reaches this line with the
# wrapper's witness missing.
cat $top/tools/used
test "$(sort -u $top/tools/used)" = "$abs/sub3"
test $(wc -l < $top/tools/used) -eq 2

# The programs landed where the Makefile said they would, which is the
# whole of what artifact_dir() is for -- a SUBPROJECT_TARGETS that
# resolved anywhere else would have failed the check the base class
# puts on it.
test -f obj/sub/target/release/hello
test -f obj/sub2/target/fake-unknown-none/debug/world
test -f obj/sub3/target/debug/tool

# The install is part of building, because a vendored tool is vendored
# so the rest of this build can run it and the rest of this build
# happens during "make" rather than during "make install".
test -f obj/stage/bin/world

# Both of them into the one directory, which is what a project that
# vendors several trees and wants their programs in one "bin" writes.
test -f obj/stage/bin/tool

# The crate that wasn't asked to install didn't.
test ! -e obj/stage/bin/hello

# And still nothing was written inside any of the trees: cargo's habit
# of making a "target" beside the manifest is the thing --target-dir
# exists to stop, and the stale one that was already there was left
# alone rather than built into.
diff - sub/target/debug/hello <<'EOF'
stale
EOF
test ! -e sub2/target
test ! -e sub3/target

##############################################################################
# A second make doesn't go back in                                           #
##############################################################################
# Which is the whole of what the source list is for.  Cargo would have
# decided nothing changed and said so, but it would have taken a
# process to say it, and a tree of vendored crates is a lot of
# processes to start before make can report there was nothing to do.
make $MAKE_ARGS > second.out
cat second.out
if grep -q CARGO second.out
then
    exit 1
fi

##############################################################################
# Touching a source gets us back in                                          #
##############################################################################
sleep 2s
touch sub/src/main.rs
make $MAKE_ARGS > third.out
cat third.out
grep -q "CARGO${tab}sub$" third.out

# And the crate that waits on it goes again too, since a --depend on a
# tree that has been rebuilt is a tree that has been rebuilt.
grep -q "CARGO${tab}sub2$" third.out

##############################################################################
# And so does the crate's own cargo configuration                            #
##############################################################################
# Which is a file whose name starts with a '.', and the walk skips
# those on purpose -- ".git" is bigger than the crate.  This one is the
# named exception, because what is in it decides what cargo does: the
# rustflags, the linker and the vendored registry an offline build
# resolves against.
sleep 2s
touch sub/.cargo/config.toml
make $MAKE_ARGS > config.out
cat config.out
grep -q "CARGO${tab}sub$" config.out

##############################################################################
# And the older spelling of that file, in the crate that has one             #
##############################################################################
# A ".cargo/config" with no extension is what cargo read before the
# rename and still reads now, so a crate vendored with one is a crate
# configured out of it.  The walk lets the directory through by name
# and then has to let the file through too: dropped by the extension
# filter it would be a prerequisite of nothing, and editing the
# rustflags or the replaced registry of a vendored crate would leave
# the build sitting on what cargo decided last time.
#
# "sub" is not expected to go again, which is what says the
# prerequisite landed on the rule for the crate that owns the file
# rather than on every rule in the Makefile.
sleep 2s
touch sub2/.cargo/config
make $MAKE_ARGS > legacy-config.out
cat legacy-config.out
grep -q "CARGO${tab}sub2$" legacy-config.out
if grep -q "CARGO${tab}sub$" legacy-config.out
then
    exit 1
fi

##############################################################################
# So does changing what the crate is built with                              #
##############################################################################
# The options are the one prerequisite of this rule that pconfigure
# writes: every other file it names is one the crate already had, so a
# build told to do something different would find all of them exactly
# as it left them and do nothing.
sed -e 's|^CONFIGUREOPTS += --jobs 3$|CONFIGUREOPTS += --jobs 5|' \
    Configfile > Configfile.new
mv Configfile.new Configfile

sleep 2s
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS > fourth.out
cat fourth.out
grep -q "CARGO${tab}sub$" fourth.out

cat $fakedir/hello.build.args
grep -q -- "^5$" $fakedir/hello.build.args

##############################################################################
# And re-running pconfigure over an unchanged Configfile doesn't              #
##############################################################################
# A file rewritten on every configure would rebuild everything below
# it on every configure, which is a worse bug than any it fixes.
sleep 2s
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS > fifth.out
cat fifth.out
if grep -q CARGO fifth.out
then
    exit 1
fi

##############################################################################
# Cleaning                                                                   #
##############################################################################
# A clean takes the stamp and nothing else: what cargo built is
# cargo's, and throwing away a target directory cargo would have
# reused is minutes of somebody's day in exchange for nothing.  Losing
# the stamp is enough to make the next make run cargo again, which is
# all a clean has to promise.
make $MAKE_ARGS clean
test ! -e obj/sub/build-stamp
test -d obj/sub/target

make $MAKE_ARGS > sixth.out
cat sixth.out
grep -q "CARGO${tab}sub$" sixth.out

# A cache-clean reclaims the object directory by reading the Makefile
# back and deleting everything under there that no rule in it builds.
# What a vendored build system put in its own output directory is
# pruned out of that, so cargo's target directory survives a build it
# would otherwise have to do again from nothing.
#
# The install root is the other half of the same statement, and it
# needs the pruning more: nothing in the Makefile builds what cargo
# installs -- the stamp's recipe puts it there -- so an unpruned
# install root would be emptied right here while the stamp that says
# the tools are installed stayed behind, and the next make would find
# nothing to do.  Both crates that install install into "obj/stage",
# which is inside the object directory and outside either crate's own
# output directory: that is what an install prefix is, and it is the
# shape the pruning has to be told about by name.
make $MAKE_ARGS cache-clean
test -f obj/stage/bin/world
test -f obj/stage/bin/tool
test -f obj/sub/target/release/hello
test -f obj/sub/build-stamp

make $MAKE_ARGS > seventh.out
cat seventh.out
if grep -q CARGO seventh.out
then
    exit 1
fi

# A distclean says the object directory as a whole is no longer
# wanted, which is where cargo's target directory lives -- and it
# still leaves the vendored crates exactly as they were found.
#
# What the crates installed goes with it and is never named: an
# install root is a directory inside the object directory, so the one
# "rm -rf" that was always there covers it.  That is the whole reason
# the rule about where an install root may point is worth having --
# the alternative is a distclean that reads a path out of a Configfile
# and removes whatever it finds there.
sed -n '/^distclean:/,/^$/p' Makefile > distclean.rule
cat distclean.rule
grep -q "rm -rf 'obj'$" distclean.rule
if grep -q "rm -rf 'obj/stage'" distclean.rule
then
    exit 1
fi

make $MAKE_ARGS distclean
test ! -e obj
test ! -e Makefile
test ! -e obj/stage

test -f sub/Cargo.toml
test -f sub/src/main.rs
test -f sub/.cargo/config.toml
test -f sub2/Cargo.toml
test -f sub2/.cargo/config
test -f sub3/Cargo.toml

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
    {
        echo "[package]"
        echo 'name = "hello"'
    } > $top/$1/sub/Cargo.toml

    {
        echo "BUILD_SYSTEMS += cargo"
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

    # A configure that stopped wrote no Makefile.  Half a Makefile is
    # worse than none at all, since make would go ahead and use it.
    test ! -e $top/$1/Makefile
}

# Nothing written out of here is a make, so a MAKEOPS has no command
# line to go on.  Refusing it is what turns a line that would have
# been quietly dropped into a line that says what to write instead.
refuses makeops "MAKEOPS       += RUSTFLAGS=-g"
grep -q "MAKEOPS doesn't apply to a cargo subproject" $top/makeops.out

# The escape hatch doesn't get to say the things this build system has
# already decided, because two answers to one question is a crate that
# builds somewhere nothing goes looking for it.
refuses target-dir "CONFIGUREOPTS += --arg --target-dir=elsewhere"
grep -q "which this build system decides for itself" $top/target-dir.out
grep -q "keeps it out of the vendored tree" $top/target-dir.out

# And the same for the three arguments that decide which directory a
# built program lands in, which is what a SUBPROJECT_TARGETS is named
# relative to.
refuses arg-profile "CONFIGUREOPTS += --arg --release"
grep -q "write '--profile NAME' or '--release' as a CONFIGUREOPTS of its own" \
     $top/arg-profile.out

# Including the short spelling of it, which is the same flag and moves
# the same directory: a "-r" that got through would build into
# "release" while everything out here went on saying "debug", and what
# somebody would see is a SUBPROJECT_TARGETS that stopped resolving.
refuses arg-release-short "CONFIGUREOPTS += --arg -r"
grep -q "write '--profile NAME' or '--release' as a CONFIGUREOPTS of its own" \
     $top/arg-release-short.out

# And the long spelling of the same thing, which is the one somebody
# writes when they have read cargo's manual rather than ours.
refuses arg-profile-long "CONFIGUREOPTS += --arg --profile=release"
grep -q "write '--profile NAME' or '--release' as a CONFIGUREOPTS of its own" \
     $top/arg-profile-long.out

# And the cluster, which is the spelling a list of names cannot see at
# all: a shell reads "-qr" as a "-q" and an "-r", cargo reads it the
# same way, and what it means is "--release" written where nothing was
# looking for it.  Nothing in a Configfile has to be written that way
# on purpose for this to matter -- it is the one of these spellings
# that gets through quietly, since cargo takes it without a word and
# builds into a directory this build system never names.
refuses arg-release-cluster "CONFIGUREOPTS += --arg -qr"
grep -q "write '--profile NAME' or '--release' as a CONFIGUREOPTS of its own" \
     $top/arg-release-cluster.out

# The machine is the other half of the directory a program lands in,
# and it is decided out here for the same reason the profile is.
refuses arg-target "CONFIGUREOPTS += --arg --target=riscv64gc-unknown-linux-gnu"
grep -q "write '--target TRIPLE' as a CONFIGUREOPTS of its own" \
     $top/arg-target.out

# Which crate is being built is the SUBPROJECTS' to say, so the
# argument that says it again is refused.  cargo writes a
# "--manifest-path" of its own into every one of these recipes, so
# what a second one produces today is cargo's "cannot be used multiple
# times" in the middle of a build -- an error a long way from the line
# that caused it, rather than a line quoted back.
refuses arg-manifest "CONFIGUREOPTS += --arg --manifest-path=other/Cargo.toml"
grep -q "there's nothing left for this to point at" $top/arg-manifest.out

# Including the one-letter spelling with the path stuck to it, which
# is a word with no name in it anywhere: "-m../other/Cargo.toml" is
# how cargo reads a manifest path and how nothing else reads anything.
refuses arg-manifest-short "CONFIGUREOPTS += --arg -m../other/Cargo.toml"
grep -q "there's nothing left for this to point at" \
     $top/arg-manifest-short.out

# A "--config" is an escape hatch inside an escape hatch: it says any
# setting cargo has, by cargo's own name for it, and three of those
# names are three things this build system has already decided --
# "build.target-dir", "build.target" and "install.root".  It also
# takes the name of a file to read settings out of, so what is in one
# is not a thing that can be read from here at all.
refuses arg-config "CONFIGUREOPTS += --arg --config=build.target=riscv64gc-unknown-linux-gnu"
grep -q "says any setting cargo has" $top/arg-config.out
grep -q "refused whatever is written after it" $top/arg-config.out

# And the one that walks out of the object directory without calling
# itself an install: it copies what was built to a path of its own, in
# a recipe that runs during a plain "make".
refuses arg-artifact-dir "CONFIGUREOPTS += --arg --artifact-dir=/opt/tools"
grep -q "copies what was built to a directory of its own" \
     $top/arg-artifact-dir.out
grep -q -- "'--install DIR' is how a copy of it gets somewhere this project owns" \
     $top/arg-artifact-dir.out

# Under the name cargo called it before it was renamed, which is the
# name a pinned toolchain old enough to matter still answers to.
refuses arg-out-dir "CONFIGUREOPTS += --arg --out-dir=/opt/tools"
grep -q "copies what was built to a directory of its own" $top/arg-out-dir.out

##############################################################################
# And the arguments that only look like those                                #
##############################################################################
# The list above is a list of things cargo does rather than a rule
# about punctuation, and the way to say so is an "--arg" that goes
# through.  These two are the ones that would be refused by a check
# that read a cluster of one-letter flags without stopping where a
# shell stops: "-prand" is "--package rand" said in one word and
# "-Frare" is "--features rare", and each has the letter of a
# reserved flag sitting in the middle of a name somebody wrote.  A
# cluster ends at the first flag that takes a value, because
# everything after it in the word is that value.
#
# Configure time is the whole of what this asks about: what the crate
# then does with a package it hasn't got is cargo's business, and the
# fake above would take either of them without an opinion.
mkdir -p $top/arg-clusters/sub
{
    echo "[package]"
    echo 'name = "hello"'
} > $top/arg-clusters/sub/Cargo.toml
{
    echo "BUILD_SYSTEMS += cargo"
    echo ""
    echo "SUBPROJECTS   += sub"
    echo "CONFIGUREOPTS += --arg -prand"
    echo "CONFIGUREOPTS += --arg -Frare"
    echo "CONFIGUREOPTS += --arg -q"
    echo "CONFIGUREOPTS += --env CARGO_HOME=$top/arg-clusters/home"
} > $top/arg-clusters/Configfile
(cd $top/arg-clusters && $PTEST_BINARY $PCONFIGURE_ARGS)
test -f $top/arg-clusters/Makefile

# And they reach cargo as they were written, one quoted word each --
# which is the other half of the same statement, since an "--arg" that
# was accepted and then taken apart would be no better than one that
# was refused.
grep -q -- "'-prand'" $top/arg-clusters/Makefile
grep -q -- "'-Frare'" $top/arg-clusters/Makefile
grep -q -- "'-q'" $top/arg-clusters/Makefile

# The one variable a Rust build is told more often than any other,
# accepted for the same reason: CARGO_HOME is where cargo keeps the
# registry it has already downloaded, which is the writer's to point
# at and no answer to anything this build system has decided.
grep -q "CARGO_HOME=" $top/arg-clusters/Makefile

# The environment is the other way of saying where cargo writes, and
# it gets the same answer: which of the two cargo would have obeyed is
# a detail of cargo rather than a thing anybody meant.
refuses cargo-target-dir "CONFIGUREOPTS += --env CARGO_TARGET_DIR=elsewhere"
grep -q "sets where cargo builds" $top/cargo-target-dir.out

# Which cargo also reads under its configuration file's name for the
# same setting.  A "build.target-dir" in a config file is
# CARGO_BUILD_TARGET_DIR in the environment, and a check that knew
# only the first spelling would be a door with a second door beside
# it: cargo shadows both of them with the "--target-dir" this recipe
# writes, which is exactly why a Configfile that says otherwise and is
# silently overruled is a line saying something untrue.
refuses cargo-build-target-dir \
    "CONFIGUREOPTS += --env CARGO_BUILD_TARGET_DIR=elsewhere"
grep -q "sets where cargo builds" $top/cargo-build-target-dir.out

# And the machine, which is the one of these cargo does not shadow: a
# "--target" is on the command line only when a CONFIGUREOPTS asked
# for one, so this is read whenever nobody did -- and every program
# cargo builds moves down into a directory named after the triple
# while artifact_dir() out here goes on saying "debug".  What somebody
# would see is a SUBPROJECT_TARGETS that stopped resolving, from a
# line that named no directory at all.
refuses cargo-build-target \
    "CONFIGUREOPTS += --env CARGO_BUILD_TARGET=riscv64gc-unknown-linux-gnu"
grep -q "sets the machine cargo builds for" $top/cargo-build-target.out
grep -q "write '--target TRIPLE' as a CONFIGUREOPTS of its own" \
     $top/cargo-build-target.out

# And where it installs, which is the same question "--install"
# answers and the same rule about where the answer may point: the
# install here runs during a plain "make", so a destination nothing
# in this project decided is a "make" writing wherever that line
# pointed.
refuses cargo-install-root "CONFIGUREOPTS += --env CARGO_INSTALL_ROOT=/opt/tools"
grep -q "sets where cargo installs" $top/cargo-install-root.out
grep -q "write '--install DIR'" $top/cargo-install-root.out

# A name is matched whole rather than as the front of the line, since
# a variable that starts with the letters of one of those is a
# different variable: this one is read by somebody's build script and
# says nothing to cargo at all.
mkdir -p $top/env-longer-name/sub
{
    echo "[package]"
    echo 'name = "hello"'
} > $top/env-longer-name/sub/Cargo.toml
{
    echo "BUILD_SYSTEMS += cargo"
    echo ""
    echo "SUBPROJECTS   += sub"
    echo "CONFIGUREOPTS += --env CARGO_TARGET_DIR_STAMP=elsewhere"
} > $top/env-longer-name/Configfile
(cd $top/env-longer-name && $PTEST_BINARY $PCONFIGURE_ARGS)
grep -q "CARGO_TARGET_DIR_STAMP=" $top/env-longer-name/Makefile

# A profile is a directory name as much as it is a setting, so one
# with a path in it would name a program somewhere this build system
# would never look for it.
refuses profile-path "CONFIGUREOPTS += --profile dev/fast"
grep -q "'--profile dev/fast' isn't a profile name" $top/profile-path.out
grep -q "write something like '--profile release'" $top/profile-path.out

# Including one with a space in it, which is the other way a profile
# stops being one word -- and the one that would reach cargo as two
# arguments if it were not quoted, or as a directory nobody has if it
# were.
refuses profile-space "CONFIGUREOPTS += --profile dev fast"
grep -q "'--profile dev fast' isn't a profile name" $top/profile-space.out

# A triple is a directory name for exactly the same reason: cargo puts
# one named after it in front of the profile, so a "--target" with a
# path in it would name a program somewhere build_dir() never looks.
# The manual says so and nothing said it twice.
refuses target-path "CONFIGUREOPTS += --target riscv64gc/linux"
grep -q "'--target riscv64gc/linux' isn't a target triple" \
     $top/target-path.out
grep -q "write something like '--target riscv64gc-unknown-linux-gnu'" \
     $top/target-path.out

refuses target-space "CONFIGUREOPTS += --target riscv64gc unknown-linux-gnu"
grep -q "'--target riscv64gc unknown-linux-gnu' isn't a target triple" \
     $top/target-space.out

# A "--cargo" is a path this resolves rather than a string it hands
# over, since the recipe runs from inside the crate -- and something
# make hasn't expanded yet is not a path anything here can resolve.
# Wrapping it in an "$(abspath)" of our own would stick one absolute
# path on the end of another, which make builds without a word and
# the shell then can't find, so it is refused where it was written
# instead.
refuses cargo-expansion 'CONFIGUREOPTS += --cargo $(abspath tools/cargo)'
grep -q "'--cargo \$(abspath tools/cargo)' is a make expression" \
     $top/cargo-expansion.out
grep -q "resolved against the project that vendored the tree" \
     $top/cargo-expansion.out
grep -q "write it the way the project spells it, like '--cargo tools/cargo'" \
     $top/cargo-expansion.out

# And a "--cargo" that is two words, which is the spelling that used
# to do something: written before the quoting went in, "--cargo cargo
# +nightly" reached the shell as a program and an argument, and rustup
# honours that argument.  It reaches the shell as one quoted word now,
# because a "--cargo" is a path somebody spelled and a directory is
# allowed a space in its name -- so what it names is a program called
# "cargo +nightly", which nobody has.
#
# Neither the manual nor the header ever said it could be more than
# one word, and no test ever pinned it, so what is refused here is a
# line that only ever worked by accident.  A diagnostic that says what
# to write instead is worth more than a "command not found" in the
# middle of somebody's build.
refuses cargo-space "CONFIGUREOPTS += --cargo cargo +nightly"
grep -q "'--cargo cargo +nightly' isn't a program" $top/cargo-space.out
grep -q "a '--cargo' is one word" $top/cargo-space.out
grep -q "RUSTUP_TOOLCHAIN=nightly" $top/cargo-space.out

# And the expansion above is still an expansion rather than a space,
# which is what the order of the two checks is for: "$(abspath
# tools/cargo)" has a space in the middle of it, and what is wrong
# with that line is not the space.

refuses jobs "CONFIGUREOPTS += --jobs lots"
grep -q "'--jobs lots' isn't a number of jobs" $top/jobs.out

refuses env "CONFIGUREOPTS += --env RUSTFLAGS"
grep -q "'--env RUSTFLAGS' has no value" $top/env.out

# And the half of an "--env" that can't be quoted has to say what it
# means on its own.  A shell reads "NAME=VALUE cmd" as an assignment
# only while the name is bare -- quoted, the whole thing is the name of
# a program nobody has -- so the name reaches the recipe as it was
# written, and one with a space in it is an assignment to the wrong
# variable in front of a program called "RUST".  Which fails at build
# time on a machine that hasn't got one and doesn't fail at all on a
# machine that has.
refuses env-name "CONFIGUREOPTS += --env RUST FLAGS=-O2"
grep -q "'--env RUST FLAGS=-O2' doesn't start with a variable name" \
     $top/env-name.out
grep -q "the one part of this that can't be quoted" $top/env-name.out
grep -q "write something like '--env RUSTFLAGS=-C target-cpu=native'" \
     $top/env-name.out

# Including the one with no name in front of the '=' at all, which is
# the same mistake written with one word less.
refuses env-nameless "CONFIGUREOPTS += --env =-O2"
grep -q "'--env =-O2' doesn't start with a variable name" $top/env-nameless.out

# And a digit first, which is a name everywhere except in the one
# place this ends up: a shell reads "2FAST=x cmd" as a command called
# "2FAST=x" rather than as an assignment, so the variable is never set
# and cargo is never run.
refuses env-digit "CONFIGUREOPTS += --env 2FAST=x"
grep -q "'--env 2FAST=x' doesn't start with a variable name" $top/env-digit.out

# The positive half is the crate at the top of this file, which is
# built with an "--env RUSTFLAGS=-C target-cpu=native" and whose
# witness says the variable arrived whole -- so this is a rule about
# what a name is rather than a rule against punctuation in a value.

# What a legal install root is has one statement and one place it is
# enforced: a directory inside the object directory of the project
# that vendored the crate, named relative to that project.  See
# build_system::install_dir().  "--install" is cargo's spelling of the
# same thing "--prefix" spells elsewhere, so the diagnostics are the
# shared ones and the examples they give agree -- which is worth
# asserting, since two spellings of one rule is how it stops being one
# rule.

# Absolute, which is the same line meaning two different directories:
# the one it says to a make at the top of the tree, and the one a
# project that pulled this in as a subproject would base underneath
# itself.
refuses install-absolute "CONFIGUREOPTS += --install /opt/tools"
grep -q "'--install /opt/tools' is an absolute path" $top/install-absolute.out
grep -q "like '--install obj/toolchain'" $top/install-absolute.out

# And one that climbs out of the project, which is a directory no
# Makefile this run writes owns.  The advice is the same advice, which
# is the assertion: one question, one answer.
refuses install-outside "CONFIGUREOPTS += --install ../stage"
grep -q "'--install ../stage' reaches outside the project that wrote it" \
     $top/install-outside.out
grep -q "like '--install obj/toolchain'" $top/install-outside.out

# And anywhere outside the object directory, whatever happens to be
# there.  The vendored crate is the case this build system cares about
# most: keeping cargo's "target" out of somebody else's checkout is
# what "--target-dir" is decided out here for, and an install aimed
# back into the crate would put the files there by hand.
refuses install-inside "CONFIGUREOPTS += --install sub/stage"
grep -q "names 'sub/stage', which is outside 'obj'" $top/install-inside.out
grep -q "write a directory inside 'obj'" $top/install-inside.out

# Including the crate's own top, which is the same mistake written
# with one word less.
refuses install-is-tree "CONFIGUREOPTS += --install sub"
grep -q "names 'sub', which is outside 'obj'" $top/install-is-tree.out

# And the object directory itself, which is inside itself and is still
# not a directory inside it: "make cache-clean" spares an install
# root, so a root that is the whole object directory is a cache-clean
# that reclaims nothing at all.
refuses install-objdir "CONFIGUREOPTS += --install obj"
grep -q "'--install obj' is the object directory itself" \
     $top/install-objdir.out
grep -q "make cache-clean" $top/install-objdir.out

# A root inside the object directory is what an install root is, and
# the one line it puts in the Makefile is the cache-clean prune.
mkdir -p $top/install-objdir-own/sub
{
    echo "[package]"
    echo 'name = "hello"'
} > $top/install-objdir-own/sub/Cargo.toml
{
    echo "BUILD_SYSTEMS += cargo"
    echo ""
    echo "SUBPROJECTS   += sub"
    echo "CONFIGUREOPTS += --install obj/stage"
} > $top/install-objdir-own/Configfile
(cd $top/install-objdir-own && $PTEST_BINARY $PCONFIGURE_ARGS)
test -f $top/install-objdir-own/Makefile

grep -q -- "-not -path 'obj/stage/[*]'" $top/install-objdir-own/Makefile

# And distclean says nothing about it, because it does not have to:
# the directory it removes has the root inside it.
sed -n '/^distclean:/,/^$/p' $top/install-objdir-own/Makefile > own.rule
cat own.rule
grep -q "rm -rf 'obj'$" own.rule
if grep -q "rm -rf 'obj/stage'" own.rule
then
    exit 1
fi

##############################################################################
# And the same rule about a path that isn't a prefix                         #
##############################################################################
# A "--cargo" names a program rather than a directory, and it is read
# the same way for the same reason: it is a path written in a
# Configfile, so it is relative to the project that wrote it and may
# not climb out.  One that did would name one program to a pconfigure
# run at the top of the tree and a different one to a run inside the
# project -- and the recipe it lands in has already gone "cd" into the
# crate, so "found the wrong program" and "found no program" are both
# on the table.
#
# The crate at the top of this file pins "--cargo tools/cargo" and is
# built with it, which is the positive half of this.
refuses cargo-outside "CONFIGUREOPTS += --cargo ../tools/cargo"
grep -q "'--cargo ../tools/cargo' reaches outside the project that wrote it" \
     $top/cargo-outside.out
grep -q "like '--cargo tools/cargo'" $top/cargo-outside.out

# "cargo install" has no "--package": it installs whatever its
# "--path" names.  Passing one anyway would be a build that fails
# after the build half of the same recipe had already succeeded, which
# is a long way from the two lines that caused it.
refuses package-install "CONFIGUREOPTS += --package inner
CONFIGUREOPTS += --install obj/stage"
grep -q "'--package inner' and '--install obj/stage' can't both be given" \
     $top/package-install.out
grep -q "'cargo install' has no '--package'" $top/package-install.out
grep -q "point the SUBPROJECTS at the workspace member's own directory" \
     $top/package-install.out

# A cargo flag written where a pconfigure option goes.  It is an easy
# mistake because both of them start with two dashes, so the answer is
# the list of the ones that would have worked.
refuses unknown "CONFIGUREOPTS += --frobnicate"
grep -q "unknown CONFIGUREOPTS '--frobnicate'" $top/unknown.out
grep -q -- "--release' picks the profile" $top/unknown.out

##############################################################################
# The net under the fake, pulled on                                          #
##############################################################################
# Everything above this line is an assertion about what pconfigure
# writes, and the fake cargo is what most of them are read through: it
# refuses a command line the real cargo would refuse, so a pconfigure
# that wrote one is a "make" that stops rather than a Makefile nobody
# looked at closely enough.
#
# Which leaves the fake's own refusals in an awkward spot.  Most of
# them are unreachable through pconfigure by construction -- that is
# the point of them, and a scenario that reached one would mean the
# bug it guards against had already happened -- so nothing above ever
# runs them, and an assertion nobody runs is an assertion nobody finds
# out has stopped working.  A "$manifest" renamed in one place and not
# the other, an arm whose condition was inverted, a "1>&2" that became
# a "2>&1": each of those turns a net into a decoration, silently, and
# every test that leans on the net goes on passing.
#
# So each of them is pulled on here, by invoking the fake directly.
# That is not a test of pconfigure and doesn't pretend to be; it is
# the test of the instrument the rest of this file measures with.
#
# Two of them are leaned on hard above without ever being reached,
# which is a different thing: the "--force" arm is what the second
# install of a rebuilt crate would hit if the recipe stopped writing
# that flag, and the directory arm is what every "cwd=" assertion
# above is really about.  Leaning on an arm exercises the path that
# doesn't take it, so both are pulled on down here like all the rest.
fakenet="$top/fake-net"
mkdir -p $fakenet/crate $fakenet/empty

cat >$fakenet/crate/Cargo.toml <<'EOF'
[package]
name = "net"
version = "0.1.0"
EOF

# Runs the fake from a directory of this test's choosing and says it
# refused.  The directory is a parameter because the fake insists on
# having been run from inside the crate: one of the arms below is
# about getting that wrong, and the two after it have to get it right
# to be reached at all.  The subshell is what keeps that "cd" from
# moving the rest of the test, as well as being where a failure isn't
# fatal, which it has to be with "set -e" on.
fake_refuses()
{
    witness="$top/fake-$1.out"
    directory="$2"
    shift 2

    if (cd $directory && $fakedir/cargo "$@") > $witness 2>&1
    then
        exit 1
    fi
    cat $witness
}

# A subcommand the fake doesn't implement.  It implements two, and it
# says so rather than carrying on with an empty argument list, because
# a pconfigure that wrote "cargo rustc" would otherwise be measured by
# a fake that parsed its flags and wrote a witness as though nothing
# had happened.
fake_refuses subcommand $fakenet check --target-dir $fakenet/target
grep -q "there is no 'check' subcommand" $top/fake-subcommand.out

# Where cargo is told to write, which is the whole of what keeps a
# vendored crate's output out of the tree it was vendored from.  Not
# told at all is the first half of that, and this is also the control
# under the two "--package" runs further down: it is what they stop at
# once they get past the arm they were written for, so it says they
# stopped where this test thinks they did rather than somewhere
# earlier.
fake_refuses no-target-dir $fakenet install --root x
grep -q "run without a --target-dir" $top/fake-no-target-dir.out

# And told relatively is the other half, which is the spelling that
# would go wrong quietly: the recipe has already gone "cd" into the
# crate by the time cargo reads it, so a relative "--target-dir target"
# is the "target" beside the manifest -- exactly the directory this
# build system exists to keep cargo out of.
fake_refuses relative-target-dir $fakenet build --target-dir target
grep -q "'--target-dir target' isn't an absolute path" \
     $top/fake-relative-target-dir.out

# A build has to be pointed at a manifest, because a cargo that isn't
# looks upward from wherever it was started until it finds one -- so
# the failure this arm replaces is not an error at all, it is a build
# of somebody else's crate.
fake_refuses no-manifest $fakenet build --target-dir $fakenet/target
grep -q "run without a --manifest-path" $top/fake-no-manifest.out

# And pointed at one that is there.  A "--manifest-path" that names
# nothing is what a path resolved against the wrong directory looks
# like from in here, which is the bug the absolute spelling above is
# written to prevent -- so this arm is the one that would notice if
# the spelling stopped being absolute.
fake_refuses bad-manifest $fakenet build \
    --target-dir $fakenet/target \
    --manifest-path $fakenet/nothing/Cargo.toml
grep -q "isn't a manifest" $top/fake-bad-manifest.out

# An install needs a root, because "cargo install" with none puts the
# program in the developer's own ~/.cargo/bin -- which is a test that
# passes by writing outside its temporary directory, and then goes on
# passing on that machine forever.
fake_refuses no-root $fakenet install --target-dir $fakenet/target
grep -q "install without a --root" $top/fake-no-root.out

# And a "--no-track", without which cargo writes a .crates.toml
# alongside the bin directory saying what it thinks lives there.  That
# is wrong the moment a second vendored tree installs into the same
# prefix, which is the normal case rather than the odd one: two of the
# crates above share "obj/stage".
fake_refuses no-no-track $fakenet install \
    --target-dir $fakenet/target \
    --root $fakenet/root
grep -q "install without a --no-track" $top/fake-no-no-track.out

# And a "--path" that names a crate, since that is what "cargo
# install" installs: it has no "--package", so the directory it is
# pointed at is the whole of what it was told to build.
fake_refuses not-a-crate $fakenet install \
    --target-dir $fakenet/target \
    --root $fakenet/root \
    --no-track \
    --path $fakenet/empty
grep -q "isn't a crate" $top/fake-not-a-crate.out

# Where cargo was run, which a "--manifest-path" is not a substitute
# for: ".cargo/config.toml" is found by walking up from the current
# directory and never from beside the manifest, so a cargo run from
# the project root builds a vendored crate with the vendoring
# project's configuration.  This is the arm every "cwd=" assertion
# above is really leaning on, and this is it being run from one
# directory too high.
fake_refuses wrong-directory $fakenet build \
    --target-dir $fakenet/target \
    --manifest-path $fakenet/crate/Cargo.toml
grep -q "rather than in '.*/fake-net/crate'" $top/fake-wrong-directory.out

# An install copies what a build left behind rather than making it,
# which is what lets a build and an install that disagree about the
# profile fail here instead of quietly producing a program out of
# nothing.  A "cargo install" told nothing about the profile means
# "release" -- that is the asymmetry the recipe spells the profile out
# to avoid -- and there is nothing in this target directory at all.
fake_refuses nothing-built $fakenet/crate install \
    --target-dir $fakenet/unbuilt \
    --root $fakenet/root \
    --no-track \
    --path $fakenet/crate
grep -q "no 'net' in '.*/fake-net/unbuilt/release'" $top/fake-nothing-built.out
grep -q "nothing built it there" $top/fake-nothing-built.out

# Which is worth having only if an install that agrees with its build
# does work, so here is that: a build into "release" and an install
# that finds what it left.
(cd $fakenet/crate && $fakedir/cargo build \
    --target-dir $fakenet/target \
    --manifest-path $fakenet/crate/Cargo.toml \
    --profile release)
test -f $fakenet/target/release/net

(cd $fakenet/crate && $fakedir/cargo install \
    --target-dir $fakenet/target \
    --root $fakenet/root \
    --no-track \
    --path $fakenet/crate)
test -f $fakenet/root/bin/net

# And the second one is refused, because the real cargo will not
# overwrite a program it has already installed and with "--no-track"
# the file being there is the whole of what it looks at.  This recipe
# reruns every time the crate does, so this is what the "--force" in
# it is holding off -- and the crates above lean on that without ever
# being able to say it, since a build that reached this arm would have
# stopped rather than reported.
fake_refuses already-installed $fakenet/crate install \
    --target-dir $fakenet/target \
    --root $fakenet/root \
    --no-track \
    --path $fakenet/crate
grep -q "already exists in destination" $top/fake-already-installed.out
grep -q "Add --force to overwrite" $top/fake-already-installed.out

# And with the flag the recipe actually writes, it goes through.
(cd $fakenet/crate && $fakedir/cargo install \
    --target-dir $fakenet/target \
    --root $fakenet/root \
    --no-track \
    --force \
    --path $fakenet/crate)
test -f $fakenet/root/bin/net

# The four variables cargo reads when the command line didn't say,
# which are the four an "--env" is refused for naming.  Reaching any
# of them through pconfigure is impossible by construction -- that is
# what the refusals are for -- so they are run by hand like everything
# else in this section, and what each one says is where the program
# actually landed rather than what the fake was told.
#
# The machine first, because it is the one cargo does not shadow: a
# build with no "--target" on its command line and a
# CARGO_BUILD_TARGET in its environment writes into a directory named
# after the triple.  That is one directory below where build_dir()
# says a program is, and it is not a directory any SUBPROJECT_TARGETS
# in the project ever names -- from a Configfile line that named no
# directory at all.
(cd $fakenet/crate && CARGO_BUILD_TARGET=made-up-triple $fakedir/cargo build \
    --target-dir $fakenet/envtarget \
    --manifest-path $fakenet/crate/Cargo.toml)
test -f $fakenet/envtarget/made-up-triple/debug/net
test ! -e $fakenet/envtarget/debug/net

# And with a "--target" on the command line the command line wins,
# which is the other half of the same sentence: what is wrong with the
# variable is that it answers a question this build system has already
# answered, rather than that cargo always obeys it.
(cd $fakenet/crate && CARGO_BUILD_TARGET=made-up-triple $fakedir/cargo build \
    --target-dir $fakenet/envtarget-said \
    --manifest-path $fakenet/crate/Cargo.toml \
    --target said-outright)
test -f $fakenet/envtarget-said/said-outright/debug/net
test ! -e $fakenet/envtarget-said/made-up-triple

# Where cargo builds, under both of the names it reads that by: the
# variable of its own, and the environment's spelling of the
# "build.target-dir" a configuration file would say.
(cd $fakenet/crate && CARGO_TARGET_DIR=$fakenet/envdir $fakedir/cargo build \
    --manifest-path $fakenet/crate/Cargo.toml)
test -f $fakenet/envdir/debug/net

(cd $fakenet/crate \
    && CARGO_BUILD_TARGET_DIR=$fakenet/envdir-build $fakedir/cargo build \
    --manifest-path $fakenet/crate/Cargo.toml)
test -f $fakenet/envdir-build/debug/net

# And both shadowed by the "--target-dir" every recipe this build
# system writes carries, which is why a Configfile that sets one of
# them is a line saying something untrue rather than a build in
# somebody else's checkout -- today.  The refusal is about the line.
(cd $fakenet/crate && CARGO_TARGET_DIR=$fakenet/envdir-lost $fakedir/cargo build \
    --target-dir $fakenet/clidir \
    --manifest-path $fakenet/crate/Cargo.toml)
test -f $fakenet/clidir/debug/net
test ! -e $fakenet/envdir-lost

# And where it installs, which is the destination the whole model is
# about: an install with no "--root" puts the program wherever
# CARGO_INSTALL_ROOT pointed, during a plain "make".
(cd $fakenet/crate \
    && CARGO_INSTALL_ROOT=$fakenet/envroot $fakedir/cargo install \
    --target-dir $fakenet/target \
    --no-track \
    --force \
    --profile release \
    --path $fakenet/crate)
test -f $fakenet/envroot/bin/net

# Shadowed too, by the "--root" that is written whenever this build
# system installs at all -- and there is no install command without an
# "--install", so this is the most thoroughly shadowed of the four and
# is refused on the same terms as the rest.
(cd $fakenet/crate \
    && CARGO_INSTALL_ROOT=$fakenet/envroot-lost $fakedir/cargo install \
    --target-dir $fakenet/target \
    --root $fakenet/root \
    --no-track \
    --force \
    --profile release \
    --path $fakenet/crate)
test -f $fakenet/root/bin/net
test ! -e $fakenet/envroot-lost

# The fake cargo refuses a "--package" on an install, the way the real
# one does, and nothing pconfigure writes can reach that: the two
# options together are refused at configure time, and where there is
# no install the "--package" only ever goes on the build line.  Either
# of those could be changed by somebody who had only the other in
# mind, which is why the arm is kept -- and reaching it through
# pconfigure would mean the bug it guards against had already
# happened, which is why it is run by hand.
fake_refuses package $fakenet install --package inner
grep -q "unexpected argument '--package'" $top/fake-package.out

# Including the one-letter spelling, which is the same flag and the
# easier one to write by accident.
fake_refuses package-short $fakenet install -p inner
grep -q "unexpected argument '-p'" $top/fake-package-short.out

# And it is an install-side rule rather than a blanket one, which is
# what the two runs above can't say on their own: "cargo build" takes
# a "--package" and pconfigure writes one there, so a fake that
# refused the flag outright would have made the crate above untestable
# rather than made anything safer.
(cd $fakenet/crate && $fakedir/cargo build \
    --target-dir $fakenet/target \
    --manifest-path $fakenet/crate/Cargo.toml \
    --package net)
test -f $fakenet/target/debug/net

##############################################################################
# The selection flags, with values a shell would take apart                  #
##############################################################################
# Every one of these values came out of a Configfile, and a Configfile
# is text: what stops "--bin hello world" from reaching cargo as a
# "--bin hello" and a stray "world" is that the value is quoted on its
# way onto the command line, and that is a thing no assertion above
# makes.  The crate up top says "--features one two", which pins the
# one call site out of five that happens to be spelled with a space in
# this test's own Configfile, and says nothing whatever about the
# other four -- so each of them is written here with a value the shell
# would do something with, and the witness is asked for all of them at
# once.
#
# The two halves of that are different failures and both are worth
# having.  A "--bin hello world" is the mistake somebody makes -- two
# binaries want two "--bin" flags, and writing them as two words is
# the natural wrong guess -- and what should come of it is cargo
# saying it has no binary of that name, rather than the shell handing
# cargo an argument nobody wrote.  A ';' is the other kind: a profile
# and a triple are each checked at configure time for being "one
# word", but that check is about a directory name and refuses a space
# and a slash, which is not the same question a shell asks.  Unquoted,
# "--profile a;b" ends the command that builds the crate and starts
# one called "b".
mkdir -p $top/quoting/sub/src
{
    echo "[package]"
    echo 'name = "quoting"'
    echo 'version = "0.1.0"'
} > $top/quoting/sub/Cargo.toml
echo 'fn main() {}' > $top/quoting/sub/src/main.rs

cat >$top/quoting/Configfile <<'EOF'
BUILD_SYSTEMS += cargo

SUBPROJECTS   += sub
CONFIGUREOPTS += --profile a;b
CONFIGUREOPTS += --target x;y
CONFIGUREOPTS += --bin hello world
CONFIGUREOPTS += --package one two
CONFIGUREOPTS += --package= spaced
EOF

cd $top/quoting
$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# Written down before make is asked to run it, because the two say
# different things: this is that the quoting reached the Makefile, and
# the witness below is that a shell then read it the way it was meant.
# A recipe can be quoted wrongly and still work by luck on a value
# that has nothing in it for the shell to find, and a value that does
# can be mangled by something further along than the quoting.
grep -q -- "--profile 'a;b'" Makefile
grep -q -- "--target 'x;y'" Makefile
grep -q -- "--bin 'hello world'" Makefile
grep -q -- "--package 'one two'" Makefile

make $MAKE_ARGS > quoting.out

# And what cargo was actually handed, one line per argument, so that
# an argument with a space in it can be told from two arguments.  This
# is the assertion the greps above cannot make: it is a shell's answer
# rather than a reading of the recipe.
sed -e "s|^$abs/|TOP/|" -e "s|^$top/|TOP/|" \
    $fakedir/quoting.build.args > quoting-args
cat quoting-args
cat >expected-quoting-args <<'EOF'
--manifest-path
TOP/quoting/sub/Cargo.toml
--target-dir
TOP/quoting/obj/sub/target
--profile
a;b
--target
x;y
--bin
hello world
--package
one two
--package
spaced
EOF
diff expected-quoting-args quoting-args

# The last of those is the option written the other way round -- an
# "--flag=value" rather than a "--flag value", which is a spelling the
# reader takes either of -- with the gap left in front of the value.
# The reader hands the option over with single spaces in it, so that
# gap is still there when the value is split off and something has to
# take it off: left on, it is inside the quoting rather than outside
# it, and cargo is asked for a package whose name begins with a
# space.  Which is a thing only an exact witness can see, since a
# recipe is full of spaces and one more in it reads as nothing at all.
#
# And nothing called "b" ever ran, which is the thing a ';' does when
# it gets through: the recipe would have stopped at the profile and
# handed the rest of the line to a command of that name.  Asserted on
# the build's own output rather than inferred from the witness above,
# since a recipe that split in two would have written the witness from
# its first half and looked like a success from there.
if grep -q "b:.*not found" quoting.out
then
    exit 1
fi

cd $top

##############################################################################
# A crate, a toolchain and an install root with an apostrophe in the name    #
##############################################################################
# Every path this build system writes into a recipe came from a
# Configfile one way or another: the SUBPROJECTS line named the tree,
# the object directory underneath is named after the tree, and the
# "--cargo" and the "--install" were written out by hand.  A
# directory is allowed an apostrophe in its name -- the filesystem
# takes one, nothing in pconfigure refuses one, and people do it --
# and unquoted in a recipe that apostrophe is not a path at all: the
# shell reads the rest of the line as a string and dies looking for
# the quote that closes it.
#
# Which happens during a build rather than during a configure, and
# several lines below the SUBPROJECTS that caused it, so the whole of
# this is about making it happen here instead.  One project is enough
# to say it: the crate's own directory, the program it is built with,
# the directory it installs into and the stamp that says it was built
# are, between them, every way this build system has of writing a
# path into a recipe.
mkdir -p "$top/apostrophe/it's/src" $top/apostrophe/tools

{
    echo "[package]"
    echo 'name = "apos"'
    echo 'version = "0.1.0"'
} > "$top/apostrophe/it's/Cargo.toml"
echo 'fn main() {}' > "$top/apostrophe/it's/src/main.rs"

# The pinned toolchain, with the apostrophe in its own name rather
# than only in the directory above it: a "--cargo" is resolved and
# made absolute out here, so it is the paste site furthest from where
# it was written and the one where a quote that went missing would be
# hardest to read back.
cat >"$top/apostrophe/tools/it's-cargo" <<EOF
#!/bin/sh
pwd -P >> "$top/apostrophe/tools/used"
exec "$fakedir/cargo" "\$@"
EOF
chmod +x "$top/apostrophe/tools/it's-cargo"

cat >$top/apostrophe/Configfile <<'EOF'
BUILD_SYSTEMS += cargo

SUBPROJECTS   += it's
CONFIGUREOPTS += --cargo tools/it's-cargo
CONFIGUREOPTS += --install obj/it's-stage
EOF

cd $top/apostrophe
$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# What the recipe says, written down as a file rather than as a list
# of arguments.  Each of these is a line of shell quoting, and putting
# one through a second round of quoting to get it onto a grep command
# line is how an assertion about quoting stops saying what it means --
# so the heredoc is the quoted kind, every fragment below is literally
# what the Makefile has to contain, and grep is told they are fixed
# strings.
cat >expected-fragments <<'EOF'
@mkdir -p 'obj/it'\''s'
@cd 'it'\''s' && '$(abspath tools/it'\''s-cargo)' build
--manifest-path '$(abspath it'\''s/Cargo.toml)'
--target-dir '$(abspath obj/it'\''s/target)'
@mkdir -p 'obj/it'\''s-stage'
--path '$(abspath it'\''s)'
--root '$(abspath obj/it'\''s-stage)'
@date > 'obj/it'\''s/build-stamp'
EOF

while read -r fragment
do
    grep -q -F -- "$fragment" Makefile
done < expected-fragments

# And then the part no reading of the Makefile can say, which is that
# a shell agrees: every one of those lines runs, in order, and the
# build finishes.  A single missing quote anywhere above is a syntax
# error here rather than a wrong path, because the rest of the recipe
# goes inside the string the shell is still looking for the end of.
make $MAKE_ARGS > apostrophe.out
cat apostrophe.out

# The stamp, which is the "$@" that isn't written as one: make would
# have handed the shell a redirection it can't parse.
test -f "obj/it's/build-stamp"

# The crate was built by the program the Configfile pinned, from
# inside the crate, on both halves of the recipe -- so the "--cargo"
# survived being made absolute and quoted, twice.
test "$(sort -u "$top/apostrophe/tools/used")" = "$abs/apostrophe/it's"
test $(wc -l < "$top/apostrophe/tools/used") -eq 2

# And what cargo was handed, one line per argument: the apostrophe is
# still in the middle of one path each time rather than having ended
# a word or been dropped.
sed -e "s|^$abs/|TOP/|" -e "s|^$top/|TOP/|" \
    $fakedir/apos.build.args > apostrophe-args
cat apostrophe-args
cat >expected-apostrophe-args <<'EOF'
--manifest-path
TOP/apostrophe/it's/Cargo.toml
--target-dir
TOP/apostrophe/obj/it's/target
EOF
diff expected-apostrophe-args apostrophe-args

# Including the install, whose root is the other path a Configfile
# wrote by hand here.
sed -e "s|^$abs/|TOP/|" -e "s|^$top/|TOP/|" \
    $fakedir/apos.install.args > apostrophe-install-args
cat apostrophe-install-args
cat >expected-apostrophe-install-args <<'EOF'
--path
TOP/apostrophe/it's
--root
TOP/apostrophe/obj/it's-stage
--target-dir
TOP/apostrophe/obj/it's/target
--no-track
--force
--profile
dev
EOF
diff expected-apostrophe-install-args apostrophe-install-args

# And the program landed in the root that was asked for rather than in
# a directory whose name stops at the apostrophe.
test -f "obj/it's-stage/bin/apos"

cd $top

##############################################################################
# A crate a subproject vendored, rather than one the top of the run did      #
##############################################################################
# Everything above this line is a crate vendored by the project
# pconfigure was run in, which is the case where a path written in a
# Configfile and a path make will read are the same string.  They are
# not the same string anywhere else: a project pulled in as a
# SUBPROJECTS is reached through a variable that says where it is, so
# "tools/cargo" written down there is "$(pconfigure_subdir_psub)tools/
# cargo" to the make that reads it from up here -- and the same line
# is plain "tools/cargo" again to a make run inside the subproject,
# which is why the variable exists rather than the path being written
# out.
#
# A "--cargo" is the option that has to be resolved for that to come
# out right, since it is the one this build system makes absolute out
# here: resolved a level too high it names a program belonging to
# whoever ran pconfigure rather than to the project that wrote the
# line.  Which is a failure with two shapes, and the worse of them is
# the quiet one -- "no such file" if there is nothing up there, and
# somebody else's program run without being asked for if there is.
#
# So there is a decoy up there, and it is a program that fails: a run
# that reaches it says so rather than building the crate with the
# wrong toolchain and passing.
mkdir -p $top/nested/tools $top/nested/psub/tools $top/nested/psub/crate/src

{
    echo "[package]"
    echo 'name = "nest"'
    echo 'version = "0.1.0"'
} > $top/nested/psub/crate/Cargo.toml
echo 'fn main() {}' > $top/nested/psub/crate/src/main.rs

cat >$top/nested/tools/cargo <<EOF
#!/bin/sh
echo "the wrong cargo, resolved a level too high" 1>&2
date > $top/nested/decoy-ran
exit 1
EOF
chmod +x $top/nested/tools/cargo

cat >$top/nested/psub/tools/cargo <<EOF
#!/bin/sh
pwd -P >> "$top/nested/psub/tools/used"
exec "$fakedir/cargo" "\$@"
EOF
chmod +x $top/nested/psub/tools/cargo

cat >$top/nested/Configfile <<'EOF'
SUBPROJECTS += psub
EOF

cat >$top/nested/psub/Configfile <<'EOF'
BUILD_SYSTEMS += cargo

SUBPROJECTS   += crate
CONFIGUREOPTS += --cargo tools/cargo
CONFIGUREOPTS += --install obj/stage
EOF

##############################################################################
# Configured from the top                                                    #
##############################################################################
cd $top/nested
$PTEST_BINARY $PCONFIGURE_ARGS
cat psub/obj/Makefile.psub

# Every path in the recipe reaches the subproject through the variable
# that says where it is, which is what makes one generated fragment
# readable by a make standing in either place.  The "--cargo" is the
# one of them that was written by hand rather than worked out from the
# SUBPROJECTS line, and it goes through the same variable.
grep -q -- "cd '\$(pconfigure_subdir_psub)crate' && '\$(abspath \$(pconfigure_subdir_psub)tools/cargo)' build" \
     psub/obj/Makefile.psub
grep -q -- "--root '\$(abspath \$(pconfigure_subdir_psub)obj/stage)'" \
     psub/obj/Makefile.psub

# And the spelling that comes of resolving it against whoever ran
# pconfigure instead, which names the decoy beside the top Configfile.
if grep -q -- "\$(abspath tools/cargo)" psub/obj/Makefile.psub
then
    exit 1
fi

make $MAKE_ARGS > nested.out
cat nested.out

# The subproject's own cargo ran, from inside the crate, on both
# halves of the recipe.
test "$(sort -u $top/nested/psub/tools/used)" = "$abs/nested/psub/crate"
test $(wc -l < $top/nested/psub/tools/used) -eq 2

# And the one a level up never did, which is the half of this that a
# reading of the Makefile can't promise on its own.
test ! -e $top/nested/decoy-ran

test -f psub/obj/crate/build-stamp
test -f psub/obj/stage/bin/nest

##############################################################################
# ... and configured again from inside the subproject                        #
##############################################################################
# Where the same line means a path with nothing in front of it, since
# there is no project above this one to be reached through.  This is
# the run that would have gone on working if the resolution were wrong
# -- it is the one everybody tries first -- so it is worth having
# beside the one above rather than instead of it.
#
# The stamp and what the install left go first, since nothing else
# here has changed and a make that found the stamp newer than the
# crate would have nothing to do and nothing to say.
rm -f psub/obj/crate/build-stamp psub/obj/stage/bin/nest
: > $top/nested/psub/tools/used

(cd psub && $PTEST_BINARY $PCONFIGURE_ARGS)

grep -q -- "cd 'crate' && '\$(abspath tools/cargo)' build" psub/Makefile
grep -q -- "--root '\$(abspath obj/stage)'" psub/Makefile

(cd psub && make $MAKE_ARGS) > nested-inside.out
cat nested-inside.out

test "$(sort -u $top/nested/psub/tools/used)" = "$abs/nested/psub/crate"
test $(wc -l < $top/nested/psub/tools/used) -eq 2
test ! -e $top/nested/decoy-ran
test -f psub/obj/stage/bin/nest

cd $top
