#include "harness_start.bash"

mkdir -p src sub/src native/src cmdline/src

##############################################################################
# A toolchain that isn't installed                                           #
##############################################################################
# Cross-compiling means running somebody else's compiler, and there
# isn't one on this machine to run.  These stand in for it: programs
# named the way a toolchain names its programs, which write down how
# they were called and then hand the whole command line to the
# compiler that is installed.
#
# What's under test here is which program pconfigure decides to name,
# not what that program does once it's named -- so a wrapper that
# forwards to cc is as good as a real aarch64 toolchain would be, and
# it has the considerable advantage of existing.  The log it leaves
# is what turns "the Makefile says faketc-gcc" into "faketc-gcc is
# what ran".
tcdir=$(pwd)/toolchain
mkdir -p $tcdir

cat >$tcdir/faketc-gcc <<EOF
#!/bin/bash
echo "faketc-gcc \$@" >> $tcdir/ran.log
exec cc "\$@"
EOF

cat >$tcdir/faketc-g++ <<EOF
#!/bin/bash
echo "faketc-g++ \$@" >> $tcdir/ran.log
exec c++ "\$@"
EOF

chmod +x $tcdir/faketc-gcc $tcdir/faketc-g++
export PATH="$tcdir:$PATH"

top=$(pwd)

##############################################################################
# A project built for somebody else's machine                                #
##############################################################################
# A CROSS_COMPILE names the prefix every program in a toolchain
# shares, which is how kbuild has spelled this since before most of
# these programs were written.  Put at the top of a Configfile it's
# what the whole project is built with, and everything below it --
# targets, the sources they're made of, and the projects a SUBPROJECTS
# pulls in -- is built for that machine unless it says otherwise.
#
# The two that say otherwise here are the shape the doc's example
# takes: a project that cross-compiles almost everything, and one tool
# that has to run on the machine doing the building.
cat >Configfile <<EOF
LANGUAGES     += c
LANGUAGES     += c++

CROSS_COMPILE  = faketc-

SUBPROJECTS   += sub

BINARIES      += hello
SOURCES       += hello.c
SOURCES       += common.c

BINARIES      += hello2
SOURCES       += hello2.c
SOURCES       += common.c

BINARIES      += hellopp
SOURCES       += hellopp.c++

BINARIES      += mkimage
CROSS_COMPILE  =
SOURCES       += mkimage.c
SOURCES       += common.c

LIBRARIES     += libmixed.so
SOURCES       += cross.c
SOURCES       += hostside.c
CROSS_COMPILE  =
EOF

cat >sub/Configfile <<EOF
LANGUAGES += c

LIBRARIES += libsub.so
SOURCES   += sub.c
EOF

# Every one of these returns non-zero unless it was linked against the
# object that belongs to it, so running them says more than "a program
# came out".
cat >src/common.c <<EOF
int common(void) { return 7; }
EOF

cat >src/hello.c <<EOF
int common(void);
int main(void) { return common() - 7; }
EOF

cat >src/hello2.c <<EOF
int common(void);
int main(void) { return common() - 7; }
EOF

cat >src/mkimage.c <<EOF
int common(void);
int main(void) { return common() - 7; }
EOF

cat >src/hellopp.c++ <<EOF
int main(void) { return 0; }
EOF

cat >src/cross.c <<EOF
int cross(void) { return 1; }
EOF

cat >src/hostside.c <<EOF
int hostside(void) { return 2; }
EOF

cat >sub/src/sub.c <<EOF
int sub(void) { return 3; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
cat sub/Makefile

##############################################################################
# What a prefix means to a language                                          #
##############################################################################
# C runs "${prefix}gcc" and C++ runs "${prefix}g++", because that's
# what the programs in a toolchain are called.  The prefix replaces
# the program and nothing else: CFLAGS and CXXFLAGS are still whoever
# runs make's business, and they're still written into the recipe as
# the make variables they always were.
grep -q 'faketc-gcc -x c ${CFLAGS} .* -c src/hello\.c -o ' Makefile
grep -q 'faketc-gcc ${LDFLAGS} ${CFLAGS} -oobj/bin/hello/[0-9]*/local' Makefile
grep -q 'faketc-gcc ${LDFLAGS} ${CFLAGS} -oobj/bin/hello/[0-9]*/install' Makefile
grep -q 'faketc-g++ -x c++ ${CXXFLAGS} .* -c src/hellopp\.c++ -o ' Makefile
grep -q 'faketc-g++ ${LDFLAGS} ${CXXFLAGS} -oobj/bin/hellopp/[0-9]*/local' Makefile

# ... and the variables that name this machine's compiler are gone
# from everything the prefix applies to.  ${CC} is whatever compiler
# the machine running make has, which is exactly the wrong one here:
# a cross build that still said ${CC} would be a native build wearing
# a cross build's name.
if grep -q '${CC}.* -c src/hello\.c -o ' Makefile
then
    exit 1
fi
if grep -q '${CXX}' Makefile
then
    exit 1
fi

# A source nobody wrote a SOURCES line about in the same breath as a
# compiler still gets the project's toolchain, which is the whole
# point of writing it once at the top.
grep -q 'faketc-gcc -x c .* -c src/common\.c -o ' Makefile

##############################################################################
# Taking it back for one target                                              #
##############################################################################
# "CROSS_COMPILE =" with nothing after the '=' clears what was
# inherited.  There's no way to write an empty word on the right of an
# '=', so the value being absent is how the parser is told, which is a
# case that exists for nothing else -- and this is what it exists for:
# a project that cross-compiles everything except the one tool that
# runs on the machine doing the building.
grep -q '${CC} -x c ${CFLAGS} .* -c src/mkimage\.c -o ' Makefile
grep -q '${CC} ${LDFLAGS} ${CFLAGS} -oobj/bin/mkimage/[0-9]*/local' Makefile
if grep -q 'faketc.* -c src/mkimage\.c -o ' Makefile
then
    exit 1
fi
if grep -q 'faketc.* -oobj/bin/mkimage/' Makefile
then
    exit 1
fi

# The same thing one scope down: written after a SOURCES line it's
# that one file that goes back to the host toolchain, and it doesn't
# reach the file listed before it or the link that gathers them both
# up.  A clear that leaked upward would quietly turn the whole library
# native.
grep -q 'faketc-gcc -x c .* -c src/cross\.c -o ' Makefile
grep -q '${CC} -x c .* -c src/hostside\.c -o ' Makefile
grep -q 'faketc-gcc ${LDFLAGS} ${CFLAGS} -oobj/lib/libmixed.so/[0-9]*/local' Makefile
if grep -q 'faketc.* -c src/hostside\.c -o ' Makefile
then
    exit 1
fi

##############################################################################
# What the link line stops saying                                            #
##############################################################################
# A prefix doesn't only change which program gets run, it changes what
# that program will accept.  The flags pconfigure adds on a Mac are
# Mach-O flags, and a CROSS_COMPILE is a project saying the thing
# coming out of the link isn't one: "@loader_path" would go in as a
# literal rpath that means nothing on the machine the binary is going
# to run on, and "-install_name" isn't an option GNU ld has at all, so
# the cross-linked library below would stop dead on it.
#
# The test is written to hold on any host.  On Linux none of these
# were ever there; on a Mac they are there for the native targets in
# this same Makefile, which is what makes their absence here mean
# something.
if grep -q 'oobj/lib/libmixed.so/[0-9]*/local.*install_name' Makefile
then
    exit 1
fi
if grep -q 'faketc-gcc.*loader_path' Makefile
then
    exit 1
fi
if grep -q 'case .*file -b obj/bin/hello/' Makefile
then
    exit 1
fi

# ... and the rpath a cross target does get is the one ELF has always
# used, so a library built next to it is still found at run time.
grep -q 'faketc-gcc .*-oobj/bin/hello/[0-9]*/local.*rpath,\\[$][$]ORIGIN/' Makefile

##############################################################################
# What a subproject inherits                                                 #
##############################################################################
# A subproject is its own project with its own Configfile, and that
# Configfile says nothing about any of this.  It's still part of the
# build that pulled it in, though, so it's built for the same machine
# -- the same way it's installed to the same PREFIX.  A subproject
# that quietly built native objects would get as far as the link
# before anybody found out.
grep -q 'faketc-gcc -x c .* -c $(pconfigure_subdir_sub)src/sub\.c -o ' sub/Makefile
grep -q 'faketc-gcc ${LDFLAGS} ${CFLAGS} -o$(pconfigure_subdir_sub)obj/lib/libsub.so/' sub/Makefile
if grep -q '${CC} ' sub/Makefile
then
    exit 1
fi

##############################################################################
# The object cache                                                           #
##############################################################################
# An object is named after everything that went into building it, and
# the toolchain that built it is one of those things.  common.c is
# built twice here -- once for the target machine by hello and hello2,
# once for this one by mkimage -- and those two have to land on paths
# of their own.
#
# Without the toolchain in that hash they'd be one file, and whichever
# target make reached first would leave an object behind that the
# other would link: a program for this machine built out of code
# compiled for another one, or the reverse, with no error anywhere
# until something refused to run.
grep -o '^obj/src/common\.c/[0-9]*-static\.o:' Makefile | sort -u > common.objs
cat common.objs
test $(wc -l < common.objs) -eq 2

# ... and no further than that.  hello and hello2 are built for the
# same machine by the same toolchain, so the object they link is the
# same one and mkimage's is the other: forking the cache on anything
# short of a real difference would just be building the same file
# twice.
grep "^obj/bin/hello/[0-9]*/local:" Makefile \
    | grep -o "obj/src/common\.c/[0-9]*-static\.o" > hello.obj
grep "^obj/bin/hello2/[0-9]*/local:" Makefile \
    | grep -o "obj/src/common\.c/[0-9]*-static\.o" > hello2.obj
grep "^obj/bin/mkimage/[0-9]*/local:" Makefile \
    | grep -o "obj/src/common\.c/[0-9]*-static\.o" > mkimage.obj
cat hello.obj hello2.obj mkimage.obj
diff -u hello.obj hello2.obj
if diff -q hello.obj mkimage.obj
then
    exit 1
fi

##############################################################################
# Building it                                                                #
##############################################################################
make $MAKE_ARGS

# The Makefile's claim about the object cache, made against the files
# that are actually on the disk.
test $(ls obj/src/common.c/*-static.o | wc -l) -eq 2

# Everything came out, and the things that are supposed to run on this
# machine run on it.  The cross-compiled ones do too, since the
# toolchain they name is a wrapper around this machine's compiler --
# what's proven by running them is that the command line pconfigure
# handed the wrapper was one a compiler could use.
./bin/hello
./bin/hello2
./bin/hellopp
./bin/mkimage
test -f lib/libmixed.so
test -f sub/lib/libsub.so

# The wrapper is what ran, for the sources that named it and for no
# others.  This is the assertion that separates "pconfigure wrote a
# program name into a Makefile" from "that program compiled the code",
# and the negative half is the one that matters: a target handed back
# to the host toolchain must never have been near the cross one.
grep -q "^faketc-gcc .* -c src/hello\.c " $tcdir/ran.log
grep -q "^faketc-gcc .* -c src/common\.c " $tcdir/ran.log
grep -q "^faketc-g++ .* -c src/hellopp\.c++ " $tcdir/ran.log
grep -q "^faketc-gcc .* -c sub/src/sub\.c " $tcdir/ran.log
if grep -q "mkimage" $tcdir/ran.log
then
    exit 1
fi

# The clear that landed on a single SOURCES line is a narrower claim,
# and so is the assertion.  "hostside.c" was compiled by the host
# toolchain, but the library it goes into is still a cross target, so
# the cross linker does see the object it produced -- that name turns
# up on the link line and is supposed to.  What must never have
# happened is the compile.
if grep -q "^faketc-gcc .* -c src/hostside\.c " $tcdir/ran.log
then
    exit 1
fi

##############################################################################
# The scopes, from the other direction                                       #
##############################################################################
# The project above starts cross and hands pieces back; this one
# starts native and hands pieces over.  Both directions are worth
# pinning down, because a CROSS_COMPILE written after a target is the
# form somebody reaches for first -- one firmware image in a project
# that's otherwise perfectly ordinary.
#
# It lands on whatever target is open rather than on the language,
# which is what lets the same line mean the same thing at all three of
# these places.  With nothing open at all, none of them is: without a
# CROSS_COMPILE anywhere, the recipes are the ${CC} and ${CXX} that
# have always been there.
cat >native/Configfile <<EOF
LANGUAGES     += c
LANGUAGES     += c++

BINARIES      += hostbin
SOURCES       += hostbin.c

BINARIES      += hostpp
SOURCES       += hostpp.c++

BINARIES      += guestbin
CROSS_COMPILE  = faketc-
SOURCES       += guestbin.c

LIBRARIES     += libguest.so
CROSS_COMPILE  = faketc-
SOURCES       += guestlib.c

TESTEXECS     += guestexec
CROSS_COMPILE  = faketc-
SOURCES       += guestexec.c

BINARIES      += mixed
SOURCES       += host_part.c
SOURCES       += guest_part.c
CROSS_COMPILE  = faketc-
EOF

cat >native/src/hostbin.c <<EOF
int main(void) { return 0; }
EOF

cat >native/src/hostpp.c++ <<EOF
int main(void) { return 0; }
EOF

cat >native/src/guestbin.c <<EOF
int main(void) { return 0; }
EOF

cat >native/src/guestlib.c <<EOF
int guestlib(void) { return 4; }
EOF

cat >native/src/guestexec.c <<EOF
int main(void) { return 0; }
EOF

cat >native/src/guest_part.c <<EOF
int guest_part(void) { return 9; }
EOF

cat >native/src/host_part.c <<EOF
int guest_part(void);
int main(void) { return guest_part() - 9; }
EOF

cd native
$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# A project that never says a word about cross-compiling gets the
# recipes it always got.  These are make variables, written into the
# Makefile literally so that whoever runs make can point CC wherever
# they like -- so grep for them literally.
grep -q '${CC} -x c ${CFLAGS} .* -c src/hostbin\.c -o ' Makefile
grep -q '${CC} ${LDFLAGS} ${CFLAGS} -oobj/bin/hostbin/[0-9]*/local' Makefile
grep -q '${CXX} -x c++ ${CXXFLAGS} .* -c src/hostpp\.c++ -o ' Makefile
grep -q '${CXX} ${LDFLAGS} ${CXXFLAGS} -oobj/bin/hostpp/[0-9]*/local' Makefile

# A BINARIES, a LIBRARIES and a TESTEXECS each open a target, and a
# CROSS_COMPILE written after one belongs to it alone.  Every source
# of that target gets it, both when compiling and when linking, and
# the targets on either side are untouched.
grep -q 'faketc-gcc -x c .* -c src/guestbin\.c -o ' Makefile
grep -q 'faketc-gcc ${LDFLAGS} ${CFLAGS} -oobj/bin/guestbin/[0-9]*/local' Makefile
grep -q 'faketc-gcc -x c .* -c src/guestlib\.c -o ' Makefile
grep -q 'faketc-gcc ${LDFLAGS} ${CFLAGS} -oobj/lib/libguest.so/[0-9]*/local' Makefile
grep -q 'faketc-gcc -x c .* -c src/guestexec\.c -o ' Makefile
grep -q 'faketc-gcc ${LDFLAGS} ${CFLAGS} -oobj/testexec/guestexec/[0-9]*/local' Makefile
if grep -q 'faketc.* -c src/hostbin\.c -o ' Makefile
then
    exit 1
fi
if grep -q 'faketc.* -c src/hostpp\.c++ -o ' Makefile
then
    exit 1
fi

# ... and one written after a SOURCES line belongs to that file alone.
# The source listed before it is still the project's business and the
# link is still the target's, which is the entire difference between
# this scope and the one above it.
grep -q 'faketc-gcc -x c .* -c src/guest_part\.c -o ' Makefile
grep -q '${CC} -x c .* -c src/host_part\.c -o ' Makefile
grep -q '${CC} ${LDFLAGS} ${CFLAGS} -oobj/bin/mixed/[0-9]*/local' Makefile
if grep -q 'faketc.* -c src/host_part\.c -o ' Makefile
then
    exit 1
fi
if grep -q 'faketc.* -oobj/bin/mixed/' Makefile
then
    exit 1
fi

make $MAKE_ARGS

./bin/hostbin
./bin/hostpp
./bin/guestbin
./bin/mixed
test -f lib/libguest.so
test -x testexec/guestexec

# The three target scopes really did reach the toolchain, and the
# source scope reached exactly the one file it named.
grep -q "^faketc-gcc .* -c src/guestbin\.c " $tcdir/ran.log
grep -q "^faketc-gcc .* -c src/guestlib\.c " $tcdir/ran.log
grep -q "^faketc-gcc .* -c src/guestexec\.c " $tcdir/ran.log
grep -q "^faketc-gcc .* -c src/guest_part\.c " $tcdir/ran.log
if grep -q "host_part" $tcdir/ran.log
then
    exit 1
fi
if grep -q "hostbin" $tcdir/ran.log
then
    exit 1
fi

cd $top

##############################################################################
# From the command line                                                      #
##############################################################################
# Which machine a tree is being built for isn't always a property of
# the tree: the same sources get configured for one machine and then
# for another, and editing a Configfile in between is no way to do
# that.  So it can be said on pconfigure's command line, in the long
# option's spelling and in the plain one, and the two have to mean the
# same thing because the manual says they do.
cat >cmdline/Configfile <<EOF
LANGUAGES     += c

BINARIES      += tool
SOURCES       += tool.c

BINARIES      += hosttool
CROSS_COMPILE  =
SOURCES       += hosttool.c
EOF

cat >cmdline/src/tool.c <<EOF
int main(void) { return 0; }
EOF

cat >cmdline/src/hosttool.c <<EOF
int main(void) { return 0; }
EOF

cd cmdline

# Configured for this machine first, since that's what a tree with
# nothing said about it means.
$PTEST_BINARY $PCONFIGURE_ARGS
grep -q '${CC} -x c ${CFLAGS} .* -c src/tool\.c -o ' Makefile
if grep -q 'faketc' Makefile
then
    exit 1
fi
grep -o '^obj/src/tool\.c/[0-9]*-static\.o:' Makefile > native.obj

# ... and then, without a word of it changing, for another one.
$PTEST_BINARY $PCONFIGURE_ARGS --cross-compile faketc-
cat Makefile
cp Makefile flag.mk
grep -q 'faketc-gcc -x c ${CFLAGS} .* -c src/tool\.c -o ' Makefile
grep -q 'faketc-gcc ${LDFLAGS} ${CFLAGS} -oobj/bin/tool/[0-9]*/local' Makefile

# The object that came out of that is not the object that came out of
# the run before it, which is what stops a reconfigure from linking
# whatever the last machine's build left lying in obj.
grep -o '^obj/src/tool\.c/[0-9]*-static\.o:' Makefile > cross.obj
cat native.obj cross.obj
if diff -q native.obj cross.obj
then
    exit 1
fi

# A Configfile can still take it back, and a command line is no
# different from the top of the first file that gets read -- so the
# target that asked for the host toolchain gets the host toolchain
# even though nobody named a machine inside the project at all.
grep -q '${CC} -x c ${CFLAGS} .* -c src/hosttool\.c -o ' Makefile
if grep -q 'faketc.* -c src/hosttool\.c -o ' Makefile
then
    exit 1
fi

# The other spelling is one argument with the spaces in it, the same
# text a Configfile would carry.  "Exactly the same as putting
# CROSS_COMPILE = <prefix> at the top of the first file that gets
# read" is a strong claim, so it's checked as one: the two runs write
# the same Makefile, byte for byte.
$PTEST_BINARY $PCONFIGURE_ARGS "CROSS_COMPILE = faketc-"
diff -u flag.mk Makefile

make $MAKE_ARGS
./bin/tool
./bin/hosttool
grep -q "^faketc-gcc .* -c src/tool\.c " $tcdir/ran.log
if grep -q "hosttool" $tcdir/ran.log
then
    exit 1
fi

exit 0
