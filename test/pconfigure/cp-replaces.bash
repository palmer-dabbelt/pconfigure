#include "harness_start.bash"

mkdir -p src

# A rebuild replaces a program or a library that something may well
# still have open.  "cp" doesn't replace a file, it opens the one
# that's there and writes through it -- so the copy that was already
# on disk and the copy that is there now are one file, and anything
# that had it mapped is running against pages that changed underneath
# it.
#
# On macOS that is fatal rather than merely rude: the kernel checks a
# Mach-O's code signature once and remembers the answer against that
# file, so a file whose contents changed while the answer stayed is a
# file the next exec of kills with SIGKILL, printing nothing.  A
# library rebuilt in place takes every tool that loads it down with
# it, and "Killed: 9" says nothing about which file or why.
#
# So a copy lands beside where it goes and is renamed over it.  The
# old file stays exactly as it was for whoever still has it, and the
# new one arrives with an identity of its own to be checked.
cat >Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash

PREFIX     = /opt/test

LIBRARIES += libgreet.so
SOURCES   += greet.c

BINARIES  += hello
DEPLIBS   += greet
SOURCES   += hello.c

BINARIES  += shell-tool
SOURCES   += shell-tool.bash
EOF

cat >src/greet.c <<EOF
int greet(void) { return 0; }
EOF

cat >src/hello.c <<EOF
int greet(void);
int main(void) { return greet(); }
EOF

cat >src/shell-tool.bash <<EOF
true
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

##############################################################################
# Configuring                                                                #
##############################################################################
# Every copy in the Makefile, whichever language wrote it: the two
# emitters are separate copies of the same handful of lines, and a fix
# in one of them looks entirely correct until somebody builds
# something the other one handles.
if grep -E "^	@?cp " Makefile | grep -qv '\$@\.tmp$'
then
    grep -E "^	@?cp " Makefile
    exit 1
fi
grep -q "^	@mv -f \$@.tmp \$@$" Makefile

##############################################################################
# Rebuilding                                                                 #
##############################################################################
make $MAKE_ARGS
make $MAKE_ARGS DESTDIR=$(pwd)/install install

inode() {
    ls -i "$1" | awk '{print $1}'
}

lib_was="$(inode lib/libgreet.so)"
bin_was="$(inode bin/hello)"
installed_was="$(inode install/opt/test/bin/hello)"
installed_sh_was="$(inode install/opt/test/bin/shell-tool)"

# The sleep is for mtime granularity, which is a second on plenty of
# filesystems.
sleep 2s
touch src/greet.c src/hello.c src/shell-tool.bash
make $MAKE_ARGS
make $MAKE_ARGS DESTDIR=$(pwd)/install install

# A different file, not the same file with different contents in it.
test "$(inode lib/libgreet.so)" != "$lib_was"
test "$(inode bin/hello)" != "$bin_was"
test "$(inode install/opt/test/bin/hello)" != "$installed_was"

# ... including the one a BASH binary gets, which languages/bash.c++
# emits rather than languages/cxx.c++: the two are separate copies of
# the same handful of lines, and a test that only exercised one of
# them wouldn't notice a fix that only landed there.
test "$(inode install/opt/test/bin/shell-tool)" != "$installed_sh_was"

# ... and what ended up there is the program, rather than a temporary
# file left lying about under a name nobody asked for.
test -x bin/hello
./bin/hello
test ! -e bin/hello.tmp
test ! -e lib/libgreet.so.tmp

exit 0
