#include "harness_start.bash"

top="$tempdir"

##############################################################################
# A lib/ of headers beside a "SRCDIR = ." source                             #
##############################################################################
# The same layout as a lib/ of library code, minus the code: the
# headers in it are read by an '#include' and never named on any line.
# pconfigure finds them all the same, because it reads the source to
# work out what the object depends on, and the "rm -rf 'lib'" that
# "make distclean" is would take them just as surely as a lib/util.c
# a SOURCES named.  So they are refused the same way, at the line that
# built what reads them, and the message says how the file was found
# since nothing on that line spells it.
mkdir -p $top/hdr/lib
echo '#define U 0' > $top/hdr/lib/u.h
printf '#include "lib/u.h"\nint main(void) { return U; }\n' > $top/hdr/main.c

cat >$top/hdr/Configfile <<'EOF'
LANGUAGES += c
SRCDIR     = .
BINARIES  += main
SOURCES   += main.c
EOF

if (cd $top/hdr && $PTEST_BINARY $PCONFIGURE_ARGS) > $top/hdr.out 2>&1
then
    cat $top/hdr.out
    # Show what the recipe that was just accepted would have done.
    (cd $top/hdr && make $MAKE_ARGS && make $MAKE_ARGS distclean)
    ls -lR $top/hdr
    exit 1
fi
cat $top/hdr.out
grep -q "^\./Configfile:3 'BINARIES += main'" $top/hdr.out
grep -q "'lib/u.h' is inside 'lib', where libraries go" $top/hdr.out
grep -q "no line names it, but '[^']*main.c[^']*' is built from it" $top/hdr.out
grep -q "'LIBDIR = libs'" $top/hdr.out
test ! -e $top/hdr/Makefile
test -f $top/hdr/lib/u.h

# The way out the message suggests is one that works: the libraries
# go somewhere else, the header stays a header, and distclean leaves
# it where it was.
{ head -n 1 $top/hdr/Configfile; echo 'LIBDIR     = libs'; tail -n +2 $top/hdr/Configfile; } > $top/hdr/Configfile.new && mv $top/hdr/Configfile.new $top/hdr/Configfile
(cd $top/hdr && $PTEST_BINARY $PCONFIGURE_ARGS)
(cd $top/hdr && make $MAKE_ARGS)
$top/hdr/bin/main
(cd $top/hdr && make $MAKE_ARGS distclean)
test ! -e $top/hdr/bin
test -f $top/hdr/lib/u.h
test -f $top/hdr/main.c

##############################################################################
# A script, and a test of it, pasting in a file from lib/                    #
##############################################################################
# A script's "#include" is a prerequisite in the same sense a header
# is, found by a different language reading a different syntax, and
# so is one in a test.  Each is refused on its own: the script's first
# and then, with that one out of the way, the test's.
mkdir -p $top/sh/lib $top/sh/test/main
echo 'x=1' > $top/sh/lib/helper.bash
printf '#include "lib/helper.bash"\necho "$x"\n' > $top/sh/main.bash
printf '#include "../../lib/helper.bash"\nexit 0\n' \
    > $top/sh/test/main/uses-helper.bash

cat >$top/sh/Configfile <<'EOF'
LANGUAGES += bash
SRCDIR     = .
BINARIES  += main
SOURCES   += main.bash
TESTSRC   += uses-helper.bash
EOF

if (cd $top/sh && $PTEST_BINARY $PCONFIGURE_ARGS) > $top/sh.out 2>&1
then
    cat $top/sh.out
    exit 1
fi
cat $top/sh.out
grep -q "'lib/helper.bash' is inside 'lib', where libraries go" $top/sh.out
grep -q "no line names it, but 'bin/main' is built from it" $top/sh.out
test -f $top/sh/lib/helper.bash

printf 'x=1\necho "$x"\n' > $top/sh/main.bash
if (cd $top/sh && $PTEST_BINARY $PCONFIGURE_ARGS) > $top/sh.out 2>&1
then
    cat $top/sh.out
    exit 1
fi
cat $top/sh.out
grep -q "'lib/helper.bash' is inside 'lib', where libraries go" $top/sh.out
grep -q "no line names it, but '[^']*uses-helper.bash' is built from it" \
    $top/sh.out
test -f $top/sh/lib/helper.bash

##############################################################################
# What the build writes is not a source                                      #
##############################################################################
# A prerequisite some rule in the run builds is output, wherever it
# lands: a library the binary links against sits in lib/ by design,
# and a header a GENERATE writes sits in the object directory.  Neither
# is anything distclean shouldn't take.  Configured again after the
# build, so the generated header is there on disk to be found.
export PATH="$(dirname "$PTEST_BINARY"):$PATH"
mkdir -p $top/out/src
echo 'int f(void) { return 0; }' > $top/out/src/f.c
echo 'int f(void);' > $top/out/src/f.h
cat >$top/out/src/g.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     ;;
--generate) echo "#define G 0" ;;
esac
EOF
chmod +x $top/out/src/g.h.proc
printf '#include "f.h"\n#include "g.h"\nint main(void) { return f() + G; }\n' \
    > $top/out/src/main.c

cat >$top/out/Configfile <<'EOF'
LANGUAGES += c
LIBRARIES += libf.so
SOURCES   += f.c
BINARIES  += main
LINKOPTS  += -lf
SOURCES   += main.c
GENERATE  += g.h
EOF

(cd $top/out && $PTEST_BINARY $PCONFIGURE_ARGS)
(cd $top/out && make $MAKE_ARGS)
LD_LIBRARY_PATH=$top/out/lib $top/out/bin/main
(cd $top/out && $PTEST_BINARY $PCONFIGURE_ARGS)

exit 0
