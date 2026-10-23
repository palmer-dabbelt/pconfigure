#include "harness_start.bash"

top="$tempdir"

# A static archive is put together by "ar", never linked, and has
# nowhere to write down that its members need some other library.  So
# a DEPLIBS or a LINKOPTS on a "libfoo.a" would be read by nothing --
# and before LIBRARIES built archives, a "libfoo.a" was a shared
# object that recorded those dependencies for whatever linked it.
# Taking the line quietly now would move the failure to an undefined
# reference in some other target's link, so pconfigure refuses it,
# names the line, and says to put it on whatever links the archive.

mkdir -p $top/deplibs
cat >$top/deplibs/Configfile <<'EOF'
LANGUAGES += c

LIBRARIES += libsub.a
DEPLIBS   += m
SOURCES   += sub.c
EOF

if (cd $top/deplibs && $PTEST_BINARY $PCONFIGURE_ARGS) > $top/deplibs.out 2>&1
then
    echo "DEPLIBS under a static archive was accepted" >&2
    exit 1
fi
cat $top/deplibs.out
grep -q "Configfile:4" $top/deplibs.out
grep -q "DEPLIBS under 'libsub.a', which is a static archive" $top/deplibs.out
grep -q "write 'DEPLIBS += m' under each BINARIES or LIBRARIES that has a 'DEPLIBS += sub'" $top/deplibs.out
test ! -e $top/deplibs/Makefile

mkdir -p $top/linkopts
cat >$top/linkopts/Configfile <<'EOF'
LANGUAGES += c

LIBRARIES += libsub.a
LINKOPTS  += -lpthread
SOURCES   += sub.c
EOF

if (cd $top/linkopts && $PTEST_BINARY $PCONFIGURE_ARGS) > $top/linkopts.out 2>&1
then
    echo "LINKOPTS under a static archive was accepted" >&2
    exit 1
fi
cat $top/linkopts.out
grep -q "Configfile:4" $top/linkopts.out
grep -q "LINKOPTS under 'libsub.a', which is a static archive" $top/linkopts.out
test ! -e $top/linkopts/Makefile

# A LINKER names the program that links a target, and an archive isn't
# linked by anything, so the linker it names would never run.  Before
# LIBRARIES built archives it did run, which is why this is refused
# rather than ignored: a Configfile that relied on it would otherwise
# quietly get a link from a different linker, somewhere else.
mkdir -p $top/linker
cat >$top/linker/Configfile <<'EOF'
LANGUAGES += c

LIBRARIES += libsub.a
LINKER     = cc
SOURCES   += sub.c
EOF

if (cd $top/linker && $PTEST_BINARY $PCONFIGURE_ARGS) > $top/linker.out 2>&1
then
    echo "LINKER under a static archive was accepted" >&2
    exit 1
fi
cat $top/linker.out
grep -q "Configfile:4" $top/linker.out
grep -q "LINKER under 'libsub.a', which is a static archive" $top/linker.out
grep -q "no linker ever runs for it" $top/linker.out
grep -q "write 'LINKER = cc' under each BINARIES or LIBRARIES that has a 'DEPLIBS += sub'" $top/linker.out
test ! -e $top/linker/Makefile

# A FRAMEWORKS is a library to link against with a macOS spelling, and
# goes nowhere on an archive for the same reason.  It's refused on
# every platform, the same way it's accepted on every platform: a
# Configfile that only works on the machine its author used is not one
# anybody can tell is wrong until somebody else builds it.
mkdir -p $top/frameworks
cat >$top/frameworks/Configfile <<'EOF'
LANGUAGES  += c

LIBRARIES  += libsub.a
FRAMEWORKS += CoreFoundation
SOURCES    += sub.c
EOF

if (cd $top/frameworks && $PTEST_BINARY $PCONFIGURE_ARGS) \
    > $top/frameworks.out 2>&1
then
    echo "FRAMEWORKS under a static archive was accepted" >&2
    exit 1
fi
cat $top/frameworks.out
grep -q "Configfile:4" $top/frameworks.out
grep -q "FRAMEWORKS under 'libsub.a', which is a static archive" \
    $top/frameworks.out
test ! -e $top/frameworks/Makefile

# A LINKOPTS or a LINKER above every target is a default for the
# language rather than something said about the archive, and is still
# meant for the programs next to it -- so those, and the same lines
# under a program or a shared library, are left alone.
mkdir -p $top/elsewhere/src
cat >$top/elsewhere/Configfile <<'EOF'
LANGUAGES += c
LINKOPTS  += -lm
LINKER     = cc

LIBRARIES += libsub.a
SOURCES   += sub.c

LIBRARIES += libshared.so
DEPLIBS   += m
LINKOPTS  += -lpthread
SOURCES   += shared.c

BINARIES  += app
DEPLIBS   += sub
DEPLIBS   += m
LINKOPTS  += -lpthread
SOURCES   += main.c
EOF
echo 'int sub(void) { return 1; }' > $top/elsewhere/src/sub.c
echo 'int shared(void) { return 2; }' > $top/elsewhere/src/shared.c
cat >$top/elsewhere/src/main.c <<'EOF'
int sub(void);
int main(void) { return sub() - 1; }
EOF

(cd $top/elsewhere && $PTEST_BINARY $PCONFIGURE_ARGS && make $MAKE_ARGS)
$top/elsewhere/bin/app
