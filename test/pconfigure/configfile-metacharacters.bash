#include "harness_start.bash"

top="$tempdir"

##############################################################################
# A shell metacharacter in a Configfile-written path is refused        #
##############################################################################
# checked_project_path() (build_system.c++) and leaves_the_project()
# (command_processor.c++) are the two places every path a Configfile
# writes is supposed to go through, and until now neither of them ever
# asked about ';', '&', '|', a backtick, '(', ')', '<', '>' or a
# newline: a value with one of those in it reaches a Makefile recipe
# as text, and a shell -- which is what runs that recipe -- reads the
# character as an instruction of its own wherever it sits, needing no
# space beside it to do it.
#
# Each of these is checked end to end: the line is accepted with zero
# diagnostics before build_system::unsafe_metacharacter() existed, and
# is refused, with no Makefile written, after it.  None of these run
# "make" -- the point is that pconfigure itself never gets far enough
# to write a recipe a shell could misread, so there is nothing here
# for a mutation that removes the check to hide behind.

##############################################################################
# LIBDIR                                                                     #
##############################################################################
# LIBDIR is pasted into a linker command line unquoted (see
# languages/cxx.c++'s _target_path), which is why this is the sharpest
# of the lot: the semicolon ends that command and hands the rest of
# the line to whatever shell runs the recipe, during a plain "make",
# with no install step in sight.
mkdir -p $top/libdir
cat >$top/libdir/Configfile <<'EOF'
LIBDIR = lib;touch PWNED;true
EOF

if (cd $top/libdir && $PTEST_BINARY $PCONFIGURE_ARGS) > $top/libdir.out 2>&1
then
    echo "LIBDIR with a ';' in it was accepted" >&2
    exit 1
fi
cat $top/libdir.out
grep -q "LIBDIR has a ';' in it" $top/libdir.out
test ! -e $top/libdir/Makefile
test ! -e $top/libdir/PWNED

##############################################################################
# SRCDIR                                                                     #
##############################################################################
mkdir -p $top/srcdir
cat >$top/srcdir/Configfile <<'EOF'
SRCDIR = src;touch PWNED;true
EOF

if (cd $top/srcdir && $PTEST_BINARY $PCONFIGURE_ARGS) > $top/srcdir.out 2>&1
then
    echo "SRCDIR with a ';' in it was accepted" >&2
    exit 1
fi
cat $top/srcdir.out
grep -q "SRCDIR has a ';' in it" $top/srcdir.out
test ! -e $top/srcdir/Makefile

##############################################################################
# SOURCES, which never reached leaves_the_project() at all before this      #
##############################################################################
# A SOURCES with no target open above it is only ever warned about --
# strict.h++'s compatibility argument applies to that one -- so this
# is written without a BINARIES above it on purpose: what is being
# proven is that the metacharacter refusal fires regardless, rather
# than depending on a target being open.
mkdir -p $top/sources
cat >$top/sources/Configfile <<'EOF'
SOURCES += x.c;touch PWNED;true
EOF

if (cd $top/sources && $PTEST_BINARY $PCONFIGURE_ARGS) > $top/sources.out 2>&1
then
    echo "SOURCES with a ';' in it was accepted" >&2
    exit 1
fi
cat $top/sources.out
grep -q "SOURCES has a ';' in it" $top/sources.out
test ! -e $top/sources/Makefile

# And the escape leaves_the_project() was already asking about, which
# SOURCES never asked at all: a "../../x.c" is accepted right up until
# this, compiled from outside the project, and its object written out
# there too -- since an object's path is its source's path pasted onto
# the object directory.
mkdir -p $top/sources-dotdot
cat >$top/sources-dotdot/Configfile <<'EOF'
LANGUAGES += c

BINARIES  += main
SOURCES   += ../../escape.c
EOF

if (cd $top/sources-dotdot && $PTEST_BINARY $PCONFIGURE_ARGS) \
    > $top/sources-dotdot.out 2>&1
then
    echo "SOURCES += ../../escape.c was accepted" >&2
    exit 1
fi
cat $top/sources-dotdot.out
grep -q "SOURCES names a file outside this project" $top/sources-dotdot.out
test ! -e $top/sources-dotdot/Makefile

##############################################################################
# GENERATE                                                                   #
##############################################################################
mkdir -p $top/generate
cat >$top/generate/Configfile <<'EOF'
LANGUAGES += h

GENERATE  += gen.h;touch PWNED;true
EOF

if (cd $top/generate && $PTEST_BINARY $PCONFIGURE_ARGS) \
    > $top/generate.out 2>&1
then
    echo "GENERATE with a ';' in it was accepted" >&2
    exit 1
fi
cat $top/generate.out
grep -q "GENERATE has a ';' in it" $top/generate.out
test ! -e $top/generate/Makefile

##############################################################################
# ENTITLEMENTS                                                               #
##############################################################################
mkdir -p $top/entitlements
cat >$top/entitlements/Configfile <<'EOF'
LANGUAGES     += c

BINARIES      += main
SOURCES       += main.c
ENTITLEMENTS  = app.plist;touch PWNED;true
EOF
echo 'int main(void) { return 0; }' > $top/entitlements/main.c

if (cd $top/entitlements && $PTEST_BINARY $PCONFIGURE_ARGS) \
    > $top/entitlements.out 2>&1
then
    echo "ENTITLEMENTS with a ';' in it was accepted" >&2
    exit 1
fi
cat $top/entitlements.out
grep -q "ENTITLEMENTS has a ';' in it" $top/entitlements.out
test ! -e $top/entitlements/Makefile

# And the escape check, which ENTITLEMENTS never asked before this
# either.
mkdir -p $top/entitlements-dotdot
cat >$top/entitlements-dotdot/Configfile <<'EOF'
LANGUAGES     += c

BINARIES      += main
SOURCES       += main.c
ENTITLEMENTS  = ../../escape.plist
EOF
echo 'int main(void) { return 0; }' > $top/entitlements-dotdot/main.c

if (cd $top/entitlements-dotdot && $PTEST_BINARY $PCONFIGURE_ARGS) \
    > $top/entitlements-dotdot.out 2>&1
then
    echo "ENTITLEMENTS += ../../escape.plist was accepted" >&2
    exit 1
fi
cat $top/entitlements-dotdot.out
grep -q "ENTITLEMENTS names a file outside this project" \
    $top/entitlements-dotdot.out
test ! -e $top/entitlements-dotdot/Makefile

##############################################################################
# PREFIX                                                                     #
##############################################################################
mkdir -p $top/prefix
cat >$top/prefix/Configfile <<'EOF'
PREFIX = /usr/local;touch PWNED;true
EOF

if (cd $top/prefix && $PTEST_BINARY $PCONFIGURE_ARGS) > $top/prefix.out 2>&1
then
    echo "PREFIX with a ';' in it was accepted" >&2
    exit 1
fi
cat $top/prefix.out
grep -q "PREFIX has a ';' in it" $top/prefix.out
test ! -e $top/prefix/Makefile

# An ordinary absolute PREFIX -- the whole reason this one gets no
# leaves_the_project() check -- still has to work: it is what
# "/usr/local", the default, already is.
mkdir -p $top/prefix-ok
cat >$top/prefix-ok/Configfile <<'EOF'
PREFIX = /opt/nowhere
EOF

(cd $top/prefix-ok && $PTEST_BINARY $PCONFIGURE_ARGS)
test -f $top/prefix-ok/Makefile

##############################################################################
# TESTDEPS and DEPTESTS                                                      #
##############################################################################
mkdir -p $top/testdeps
cat >$top/testdeps/Configfile <<'EOF'
LANGUAGES += c

BINARIES  += main
TESTDEPS  += dep.txt;touch PWNED;true
SOURCES   += main.c
EOF
echo 'int main(void) { return 0; }' > $top/testdeps/main.c

if (cd $top/testdeps && $PTEST_BINARY $PCONFIGURE_ARGS) \
    > $top/testdeps.out 2>&1
then
    echo "TESTDEPS with a ';' in it was accepted" >&2
    exit 1
fi
cat $top/testdeps.out
grep -q "TESTDEPS has a ';' in it" $top/testdeps.out
test ! -e $top/testdeps/Makefile

mkdir -p $top/deptests
cat >$top/deptests/Configfile <<'EOF'
LANGUAGES += c

BINARIES  += main
SOURCES   += main.c
DEPTESTS  += other;touch PWNED;true
EOF
echo 'int main(void) { return 0; }' > $top/deptests/main.c

if (cd $top/deptests && $PTEST_BINARY $PCONFIGURE_ARGS) \
    > $top/deptests.out 2>&1
then
    echo "DEPTESTS with a ';' in it was accepted" >&2
    exit 1
fi
cat $top/deptests.out
grep -q "DEPTESTS has a ';' in it" $top/deptests.out
test ! -e $top/deptests/Makefile

##############################################################################
# SUBPROJECTS                                                                #
##############################################################################
mkdir -p $top/subprojects
cat >$top/subprojects/Configfile <<'EOF'
SUBPROJECTS += sub;touch PWNED;true
EOF

if (cd $top/subprojects && $PTEST_BINARY $PCONFIGURE_ARGS) \
    > $top/subprojects.out 2>&1
then
    echo "SUBPROJECTS with a ';' in it was accepted" >&2
    exit 1
fi
cat $top/subprojects.out
grep -q "SUBPROJECTS has a ';' in it" $top/subprojects.out
test ! -e $top/subprojects/Makefile
test ! -e $top/subprojects/PWNED

exit 0
