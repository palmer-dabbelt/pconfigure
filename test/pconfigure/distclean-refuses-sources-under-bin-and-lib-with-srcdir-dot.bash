#include "harness_start.bash"

top="$tempdir"

##############################################################################
# Sources kept in lib/ and bin/ beside the Configfile                        #
##############################################################################
# "SRCDIR = ." is how a project with its sources at the top says so,
# and a project laid out that way very often has a lib/ of library
# code and sometimes a bin/ of programs.  Those are also the names of
# two of the directories "make distclean" removes whole with an
# "rm -rf", because everything in them is supposed to be output.  The
# Configfile says nothing at all about either directory -- they are
# the defaults -- so nothing but pconfigure is in a position to notice
# that the recipe it is about to write deletes the sources it was
# handed.  It is refused, pointing at the first line that named one.
mkdir -p $top/dot/lib $top/dot/bin
echo 'int f(void) { return 0; }' > $top/dot/lib/util.c
echo 'int f(void); int main(void) { return f(); }' > $top/dot/bin/main.c

cat >$top/dot/Configfile <<'EOF'
LANGUAGES += c
SRCDIR     = .

BINARIES  += main
SOURCES   += bin/main.c
SOURCES   += lib/util.c
EOF

if (cd $top/dot && $PTEST_BINARY $PCONFIGURE_ARGS) > $top/dot.out 2>&1
then
    cat $top/dot.out
    # Show what the recipe that was just accepted would have done.
    (cd $top/dot && make $MAKE_ARGS && make $MAKE_ARGS distclean)
    ls -lR $top/dot
    exit 1
fi
cat $top/dot.out
grep -q "^\./Configfile:5 'SOURCES += bin/main.c'" $top/dot.out
grep -q "'bin/main.c' is inside 'bin', where binaries go" $top/dot.out
grep -q "'make distclean' is an 'rm -rf' of 'bin'" $top/dot.out
test ! -e $top/dot/Makefile
test -f $top/dot/lib/util.c
test -f $top/dot/bin/main.c

##############################################################################
# Only lib/                                                                  #
##############################################################################
# The library directory is the one of these a Configfile can move, so
# the refusal says so -- and the move it suggests is one that works.
mkdir -p $top/libonly/lib
echo 'int f(void) { return 0; }' > $top/libonly/lib/util.c
echo 'int f(void); int main(void) { return f(); }' > $top/libonly/main.c

cat >$top/libonly/Configfile <<'EOF'
LANGUAGES += c
SRCDIR     = .

BINARIES  += main
SOURCES   += main.c
SOURCES   += lib/util.c
EOF

if (cd $top/libonly && $PTEST_BINARY $PCONFIGURE_ARGS) \
    > $top/libonly.out 2>&1
then
    cat $top/libonly.out
    exit 1
fi
cat $top/libonly.out
grep -q "^\./Configfile:6 'SOURCES += lib/util.c'" $top/libonly.out
grep -q "'lib/util.c' is inside 'lib', where libraries go" $top/libonly.out
grep -q "'LIBDIR = libs'" $top/libonly.out
test ! -e $top/libonly/Makefile
test -f $top/libonly/lib/util.c

sed -i '1a LIBDIR     = libs' $top/libonly/Configfile
(cd $top/libonly && $PTEST_BINARY $PCONFIGURE_ARGS)
(cd $top/libonly && make $MAKE_ARGS)
$top/libonly/bin/main
(cd $top/libonly && make $MAKE_ARGS distclean)
test ! -e $top/libonly/bin
test -f $top/libonly/lib/util.c
test -f $top/libonly/main.c

##############################################################################
# A HEADERSRC and a SRCDIR inside an output directory                        #
##############################################################################
# A HEADERSRC's source is read from the source directory the same way
# a SOURCES is, and a SRCDIR that is itself one of the output
# directories puts every source under it there, without any one line
# spelling "lib/".  Both are refused for the same reason.
mkdir -p $top/hdr/lib
echo '#define V 0' > $top/hdr/lib/v.h
cat >$top/hdr/Configfile <<'EOF'
LANGUAGES += h
SRCDIR     = .
HEADERSRC += lib/v.h
EOF

if (cd $top/hdr && $PTEST_BINARY $PCONFIGURE_ARGS) > $top/hdr.out 2>&1
then
    cat $top/hdr.out
    exit 1
fi
cat $top/hdr.out
grep -q "^\./Configfile:3 'HEADERSRC += lib/v.h'" $top/hdr.out
grep -q "'lib/v.h' is inside 'lib', where libraries go" $top/hdr.out
test -f $top/hdr/lib/v.h

mkdir -p $top/sdir/lib
echo 'int main(void) { return 0; }' > $top/sdir/lib/main.c
cat >$top/sdir/Configfile <<'EOF'
LANGUAGES += c
SRCDIR     = lib
BINARIES  += main
SOURCES   += main.c
EOF

if (cd $top/sdir && $PTEST_BINARY $PCONFIGURE_ARGS) > $top/sdir.out 2>&1
then
    cat $top/sdir.out
    exit 1
fi
cat $top/sdir.out
grep -q "^\./Configfile:4 'SOURCES += main.c'" $top/sdir.out
grep -q "'lib/main.c' is inside 'lib', where libraries go" $top/sdir.out
test -f $top/sdir/lib/main.c

##############################################################################
# The same names one directory down                                          #
##############################################################################
# What is refused is a source inside a directory distclean removes,
# not a source with "lib" or "bin" somewhere in its path: the same two
# files under the default "src" build, and distclean takes the output
# directories and leaves every source where it was.
mkdir -p $top/down/src
cp -r $top/dot/lib $top/dot/bin $top/down/src/
cat >$top/down/Configfile <<'EOF'
LANGUAGES += c
BINARIES  += main
SOURCES   += bin/main.c
SOURCES   += lib/util.c
EOF
before="$(cd $top/down && find src -print | sort)"

(cd $top/down && $PTEST_BINARY $PCONFIGURE_ARGS)
(cd $top/down && make $MAKE_ARGS)
$top/down/bin/main
(cd $top/down && make $MAKE_ARGS distclean)
test ! -e $top/down/bin

after="$(cd $top/down && find src -print | sort)"
diff -u <(echo "$before") <(echo "$after")

exit 0
