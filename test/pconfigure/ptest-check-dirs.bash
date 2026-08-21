#include "harness_start.bash"

mkdir -p src sub/src sub/test/helper

# The "ptest" that matters here is the one built alongside the
# pconfigure under test, not whichever one happens to be installed on
# the machine running the suite -- reading the check-dir list is a new
# thing for it to do, and an older copy on the PATH would quietly say
# there are no tests and be believed.
#
# $PTEST_BINARY is absolute, so the directory it sits in is the build
# this test belongs to.  That is the same trick a test uses to find
# anything else of its own; see the TESTS section of the manual.
ptest="$(dirname "$PTEST_BINARY")/ptest"

# A top-level project that has no tests of its own and pulls in one
# that does.  This is the shape that used to report nothing: "make
# report" knew to look in both projects because pconfigure wrote a
# "--check-dir" per project onto the command line, but a bare "ptest"
# typed by hand had only the one directory everybody has.
cat >Configfile <<EOF
SUBPROJECTS += sub

LANGUAGES   += c

BINARIES    += test
SOURCES     += test.c
EOF

cat >sub/Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash

LIBEXECS  += helper
SOURCES   += helper.c
TESTSRC   += works.bash
EOF

cat >src/test.c <<EOF
int main(void) { return 0; }
EOF

cat >sub/src/helper.c <<EOF
int main(void) { return 0; }
EOF

cat >sub/test/helper/works.bash <<'EOF'
$PTEST_BINARY
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

##############################################################################
# Configuring                                                                #
##############################################################################
# The whole reason this file exists rather than being made by a rule
# is that it has to be readable before anything is built: somebody who
# configures a tree and then types "ptest" gets an answer about the
# tree they configured, not about the last one that happened to get as
# far as running make.  So check it's here now, with nothing built.
test -f obj/check-dirs
test ! -e bin
test ! -e lib
test ! -e check
test ! -e sub/check
test ! -e obj/check-all-done

# One line per project, and both of them, written from where "ptest"
# will be standing when it reads them -- which is here, where the
# Makefile is.
cat >expected <<'EOF'
check
sub/check
EOF
diff expected obj/check-dirs

# The subproject got its own copy, because it's a project somebody can
# stand in and run make.  Standing there, the only test directory that
# exists is its own, and it's spelled the way it looks from there
# rather than the way it looks from the parent.
cat >sub-expected <<'EOF'
check
EOF
diff sub-expected sub/obj/check-dirs

# This is the list the Makefile's own report rules have always had,
# and the file is meant to be the same thing said out loud.
grep -q "ptest .*--check-dir check --check-dir sub/check" Makefile

##############################################################################
# Reporting                                                                  #
##############################################################################
make $MAKE_ARGS
make $MAKE_ARGS check
test -f sub/check/helper/works.bash

# What all of this was for.  No "--check-dir" anywhere on this command
# line, and it still finds the subproject's test and calls it by the
# project it came from.
"$ptest" --no-check-make-check > report.out
cat report.out
grep -q "	sub/helper/works.bash$" report.out
grep -q "^NPASS	1$" report.out
if grep -q "No tests" report.out
then
    exit 1
fi

# Saying where to look still means only there.  A caller who asks for
# one directory has said something, and the file on disk doesn't get
# to argue with it -- this top project has no tests of its own, so the
# honest answer is that there aren't any.
"$ptest" --no-check-make-check --check-dir check > explicit.out
cat explicit.out
grep -q "No tests" explicit.out
if grep -q "sub/helper/works.bash" explicit.out
then
    exit 1
fi

##############################################################################
# Cleaning                                                                   #
##############################################################################
# The subtle one.  "cache-clean" works by reading the Makefile back
# and throwing away everything under obj that it doesn't say how to
# build, and nothing in the Makefile mentions this file -- so without
# being pruned out by hand it would delete the only record of where
# the test results live, and a bare "ptest" would go back to reporting
# nothing.
make $MAKE_ARGS cache-clean
test -f obj/check-dirs
diff expected obj/check-dirs
test -f sub/obj/check-dirs

"$ptest" --no-check-make-check > after-clean.out
grep -q "	sub/helper/works.bash$" after-clean.out
if grep -q "No tests" after-clean.out
then
    exit 1
fi

# Undoing the configure takes it with the rest of the object
# directory, since what it records is a fact about a configuration
# that no longer exists.
make $MAKE_ARGS distclean
test ! -e obj/check-dirs
test ! -e obj
test ! -e sub/obj/check-dirs

##############################################################################
# A project on its own                                                       #
##############################################################################
# Nothing above should have changed what happens to a project with
# nothing underneath it: it gets a file naming the one directory it
# was always going to look in.
mkdir -p solo/src solo/test/solo
cd solo

cat >Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash

BINARIES  += solo
SOURCES   += solo.c
TESTSRC   += works.bash
EOF

cat >src/solo.c <<EOF
int main(void) { return 0; }
EOF

cat >test/solo/works.bash <<'EOF'
$PTEST_BINARY
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
test -f obj/check-dirs
diff ../sub-expected obj/check-dirs

make $MAKE_ARGS
make $MAKE_ARGS check
"$ptest" --no-check-make-check > solo.out
cat solo.out
grep -q "	solo/works.bash$" solo.out
grep -q "^NPASS	1$" solo.out
if grep -q "No tests" solo.out
then
    exit 1
fi

cd ..

exit 0
