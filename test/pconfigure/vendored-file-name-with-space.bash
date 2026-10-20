#include "harness_start.bash"

# A vendored tree with a file whose name has spaces in it, and a
# symlink to nothing.  The build
# waits on one glob per directory of the tree, and a glob's answer is a
# list of words: "dir/a - b.txt" came back as "dir/a", "-" and "b.txt",
# three prerequisites named outright that nothing could make, and make
# stopped before building anything at all.  QEMU's roms/edk2 has a
# dozen such files once its submodules are checked out.  A dangling
# symlink is the same failure by another route -- a glob lists it,
# and make can't find it -- and edk2 has one of those too.  Both
# should fall out of the guess instead, and the tree build as usual,
# with the link's neighbours still in it.

top="$tempdir"

# meson.bash's fakes, cut down to what a build needs: a setup that
# writes a build.ninja, and a ninja that leaves a mark.
mkdir -p $top/fake

cat >$top/fake/meson <<'EOF'
#!/bin/sh
set -e
shift
positional=
for arg in "$@"
do
    case "$arg" in
    -*) ;;
    *)  positional="$positional $arg";;
    esac
done
set -- $positional
mkdir -p "$1"
echo "# fake" > "$1/build.ninja"
EOF
chmod +x $top/fake/meson

cat >$top/fake/ninja <<'EOF'
#!/bin/sh
set -e
test "$1" = "-C"
echo "ninja ${3:-}" >> "$2/ninja-ran.txt"
EOF
chmod +x $top/fake/ninja

export PATH="$top/fake:$PATH"

mkdir -p $top/sub/src $top/sub/tests
cat >$top/sub/meson.build <<'EOF'
project('tool', 'c')
EOF
echo "int main(void) { return 0; }" > $top/sub/src/tool.c
echo "results" > "$top/sub/tests/report - TLS 1.2.txt"
ln -s /nonexistent/include $top/sub/src/IncludeHack

cat >$top/Configfile <<'EOF'
BUILD_SYSTEMS += meson
SUBPROJECTS   += sub
EOF

cd $top
$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

make $MAKE_ARGS > first.out 2>&1 || { cat first.out; exit 1; }
cat first.out
grep -q "^ninja $" obj/sub/build/ninja-ran.txt
grep -q "^obj/sub/build-stamp:.* sub/src/tool\.c" Makefile
if grep -q "IncludeHack" Makefile
then
    exit 1
fi

# And a build with nothing new to do doesn't go back into the tree.
make $MAKE_ARGS > settled.out 2>&1
cat settled.out
if grep -q "^BUILD" settled.out
then
    exit 1
fi

exit 0
