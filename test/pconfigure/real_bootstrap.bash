# Shared by the tests that bootstrap a real pconfigure rather than a
# stand-in.  Not a test of its own: it is #include'd, the way the
# harness is, and it is not on any TESTSRC line.
#
# The stand-in the other bootstrap tests vendor is a shell script one
# line away from the real tool, which is what keeps them fast, and it
# is also what let a whole class of bug through: a bash BINARY has no
# objects, no libraries and no pdeps fragments, so nothing about how
# the real tool is LINKED is ever exercised.  The real tool is C++
# whose link lines come out of the very fragments it writes, which is
# a dependency loop the stand-in cannot have.  These tests pay for a
# full C++ build of this tree to have it.

# The superproject: the cisc-v shape that found the bug, cut down to
# the two lines that matter -- AUTORECONFIGURE, which is what puts the
# tool on the reconfigure rule, and BOOTSTRAP -- and one binary of its
# own to show the build got past the tool.
#
# The vendored copy is this tree's source the way a checkout has it:
# the four things a build reads, and none of the outputs a build in
# $PTEST_SRCDIR may have left beside them.  Copied by name rather than
# through "git ls-files", because the tree under test need not be a
# git checkout at all -- a release tarball is a supported way to have
# one -- and without a .git the version script takes its fallback,
# which is the shape a submodule's archive gives too.
#
# The committed Makefile is written the way a project writes the one
# it commits, by running pconfigure over the tree, and then everything
# that run produced except that Makefile is thrown away, so the make
# that follows starts where a fresh clone does.
real_bootstrap_tree()
{
    mkdir -p src tools/pconfigure

    local part
    for part in bootstrap.sh Configfiles src test
    do
        cp -R "$PTEST_SRCDIR/$part" tools/pconfigure/
    done

    cat >Configfile <<'EOF'
AUTORECONFIGURE  = true
BOOTSTRAP        = tools/pconfigure
LANGUAGES       += c
BINARIES        += hello
SOURCES         += hello.c
EOF

    cat >src/hello.c <<'EOF'
#include <stdio.h>
int main(void) { printf("hello\n"); return 0; }
EOF

    $PTEST_BINARY $PCONFIGURE_ARGS
    rm -rf Makefile.pconfigure obj bin check
    rm -rf tools/pconfigure/Makefile tools/pconfigure/bin \
           tools/pconfigure/lib tools/pconfigure/obj \
           tools/pconfigure/include tools/pconfigure/testexec \
           tools/pconfigure/check
}

# Every make in these tests goes through here, under a timeout, because
# the failures this family of bug produces are not all failures: a
# fragment that is its own prerequisite restarts make forever, which a
# test would otherwise report by never finishing.
real_bootstrap_make()
{
    local out="$1"
    shift

    timeout 1200 make $MAKE_ARGS "$@" > "$out" 2>&1 || {
        cat "$out"
        return 1
    }
    cat "$out"
}

# Whether the vendored tools can run at all.  The way this breaks is a
# library linked out of an empty object list: the tool links, because
# the library exists, and then dies in the dynamic loader on its first
# run, by signal, before main().  So the question is only whether each
# one got far enough to look at its arguments -- an unknown flag is
# refused with an ordinary status, and a status from a signal is the
# loader.  pconfigure gets "--version" rather than a bogus flag, since
# any run of it but "--help" or "--version" goes on to read the
# Configfiles of the directory it is in and write a Makefile there.
real_bootstrap_tools_load()
{
    local tool status

    tools/pconfigure/bin/pconfigure --version

    for tool in pdeps psubdeps pinclude
    do
        status=0
        tools/pconfigure/bin/$tool --no-such-flag </dev/null \
            >/dev/null 2>&1 || status=$?
        if [[ "$status" -ge 128 ]]
        then
            echo "tools/pconfigure/bin/$tool died with status $status" >&2
            return 1
        fi
    done
}
