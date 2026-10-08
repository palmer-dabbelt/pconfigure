#include "harness_start.bash"

# A project a build is responsible for, holding tests, that never
# declared a suite -- in a build whose "make check" means a suite.
# It is the one mistake in this family with no symptom at all: the
# default suite is full of the other projects' tests so nothing
# reports an empty run, and the "make check" inside the project
# itself -- which is where anybody would go to find out whether its
# guards ran -- runs every one of them and says they passed.  Nothing
# downstream could tell that apart from a project whose tests ran,
# which is why it is refused up front.
#
# Rebuilt from scratch for each case, since what is being checked
# about two of them is that no Makefile comes out the far side.
setup() {
    rm -rf case
    mkdir -p case/src case/test/top case/sub/src case/sub/test/inner

    cat >case/src/top.c <<EOF
int main(void) { return 0; }
EOF

    cat >case/sub/src/inner.c <<EOF
int main(void) { return 0; }
EOF

    echo true > case/test/top/top-any.bash
    echo true > case/sub/test/inner/inner-any.bash
}

# The subshell is the assertion: "set -e" is on, so a command expected
# to fail has to be somewhere a failure isn't fatal.  Stopping before
# anything was written is part of what's being checked -- a
# half-configured tree is something the next command trips over.
refuses() {
    if (cd case && $PTEST_BINARY $PCONFIGURE_ARGS) > out 2>&1
    then
        exit 1
    fi
    cat out
    test ! -e case/Makefile
}

accepts() {
    (cd case && $PTEST_BINARY $PCONFIGURE_ARGS) > out 2>&1
    cat out
    test -e case/Makefile
}

##############################################################################
# The subproject that never said anything                                    #
##############################################################################
# "make check" at the top means the default suite, and the
# subproject's test is in it only if the subproject said so.  It
# didn't, so the build would run one test of the two it has and report
# that everything passed.
setup
cat >case/Configfile <<EOF
LANGUAGES          += c
LANGUAGES          += bash

SUBPROJECTS        += sub

TEST_SUITES        += network
DEFAULT_TEST_SUITE  = network

BINARIES           += top
SOURCES            += top.c
TESTSRC            += top-any.bash
EOF

cat >case/sub/Configfile <<EOF
LANGUAGES   += c
LANGUAGES   += bash

BINARIES    += inner
SOURCES     += inner.c
TESTSRC     += inner-any.bash
EOF

refuses
grep -q "'sub/' has 1 test and declares no test suite" out
grep -q "\"make check\" here means the 'network' suite" out
grep -q "the suites of this build are: 'network'" out
# The complaint has to say what to write, and it has to say the true
# thing about inclusion rather than the convenient one.  An
# INCLUDE_TEST_SUITES IS resolved over the whole build -- 46df8ee
# ("pconfigure: Resolve an INCLUDE_TEST_SUITES across the whole
# build"), and aggregate_test_suite_members unions every project's
# members and every project's includes before it walks the inclusions
# -- so one TEST_SUITES line naming a suite the others include really
# does reach them.  What inclusion cannot do is give a suite to a
# project that named NONE, which is the state being complained about,
# and that is the sentence the message has to land.
grep -q "TEST_SUITES line in that project's own Configfile" out
grep -q "resolved over the whole build" out
grep -q "inclusion cannot do is give a suite to a project that named none" out
# And it must NOT have gone back to the claim it used to make.
! grep -q "resolved per project" out

##############################################################################
# ... and the one line that fixes it                                         #
##############################################################################
setup
cat >case/Configfile <<EOF
LANGUAGES          += c
LANGUAGES          += bash

SUBPROJECTS        += sub

TEST_SUITES        += network
DEFAULT_TEST_SUITE  = network

BINARIES           += top
SOURCES            += top.c
TESTSRC            += top-any.bash
EOF

cat >case/sub/Configfile <<EOF
LANGUAGES   += c
LANGUAGES   += bash

TEST_SUITES += network

BINARIES    += inner
SOURCES     += inner.c
TESTSRC     += inner-any.bash
EOF

accepts
grep -q "^obj/check-suite-network-done: check/top/top-any.bash sub/check/inner/inner-any.bash$" case/Makefile

##############################################################################
# A build whose "make check" isn't a suite                                   #
##############################################################################
# Which is not this mistake and must not be refused as it.  With no
# DEFAULT_TEST_SUITE those two words mean every test the build has, so
# the subproject's tests run whether or not it ever heard of a suite;
# all it cannot be is asked for by the suite's name.  That is the
# shape test-suites-subprojects.bash leans on for its third case, and
# the shape every project had before suites existed.
setup
cat >case/Configfile <<EOF
LANGUAGES   += c
LANGUAGES   += bash

SUBPROJECTS += sub

TEST_SUITES += network

BINARIES    += top
SOURCES     += top.c
TESTSRC     += top-any.bash
EOF

cat >case/sub/Configfile <<EOF
LANGUAGES   += c
LANGUAGES   += bash

BINARIES    += inner
SOURCES     += inner.c
TESTSRC     += inner-any.bash
EOF

accepts
grep -q "^obj/check-suite-network-done: check/top/top-any.bash$" case/Makefile
grep -q "^obj/check-all-done: sub/obj/check-all-done$" case/Makefile

##############################################################################
# A subproject that named some other suite                                   #
##############################################################################
# Also not this mistake: it has had the thought, and which of the
# build's suites its tests belong in is its own business.  A project
# of nothing but hours-long harnesses belongs in the slow suite and in
# no "make check", and refusing that would be refusing an answer.
setup
cat >case/Configfile <<EOF
LANGUAGES          += c
LANGUAGES          += bash

SUBPROJECTS        += sub

TEST_SUITES        += network
TEST_SUITES        += slow
DEFAULT_TEST_SUITE  = network

BINARIES           += top
SOURCES            += top.c
# Named, so that the two suites below hold one test each and the
# subproject's membership of the slow one is the only thing either
# assertion is about.
TESTSRC[network]   += top-any.bash
EOF

cat >case/sub/Configfile <<EOF
LANGUAGES   += c
LANGUAGES   += bash

TEST_SUITES += slow

BINARIES    += inner
SOURCES     += inner.c
TESTSRC     += inner-any.bash
EOF

accepts
grep -q "^obj/check-suite-network-done: check/top/top-any.bash$" case/Makefile
grep -q "^obj/check-suite-slow-done: sub/check/inner/inner-any.bash$" case/Makefile

##############################################################################
# A subproject with no tests                                                 #
##############################################################################
# The shape every vendored tree a build pulls in has.  A project with
# nothing to run is outside every suite for a reason that has nothing
# to do with suites.
setup
rm case/sub/test/inner/inner-any.bash
cat >case/Configfile <<EOF
LANGUAGES          += c
LANGUAGES          += bash

SUBPROJECTS        += sub

TEST_SUITES        += network
DEFAULT_TEST_SUITE  = network

BINARIES           += top
SOURCES            += top.c
TESTSRC            += top-any.bash
EOF

cat >case/sub/Configfile <<EOF
LANGUAGES   += c

BINARIES    += inner
SOURCES     += inner.c
EOF

accepts
grep -q "^obj/check-suite-network-done: check/top/top-any.bash$" case/Makefile

##############################################################################
# The tree a BOOTSTRAP names is not exempt                                   #
##############################################################################
# This is the shape the mistake was actually found in, and the reason
# it sat as long as it did: a reading that had the vendored pconfigure
# exempt because it is the BOOTSTRAP rather than a SUBPROJECTS.  It
# isn't.  A bootstrap is an ordinary subproject in every way but the
# two it has to be special in -- a way to build a first pconfigure
# with none in hand, and a Makefile that says so -- and its tests
# reach a parent's suites by the same route as any other
# subproject's.
#
# The vendored tree is a stand-in, the same one bootstrap.bash uses: a
# Configfile that builds a pconfigure, a bootstrap.sh that can build
# one without a pconfigure, and a "pconfigure" that is the real one
# wearing a different path.  What is being checked is a refusal from
# the parent's configure, so nothing here has to run.
rm -rf case
mkdir -p case/src case/test/top case/vendor/pconfigure/src
mkdir -p case/vendor/pconfigure/test/pconfigure

cat >case/src/top.c <<EOF
int main(void) { return 0; }
EOF

echo true > case/test/top/top-any.bash
echo true > case/vendor/pconfigure/test/pconfigure/vendored.bash

cat >case/vendor/pconfigure/src/pconfigure.bash <<EOF
exec "$PTEST_BINARY" "\$@"
EOF

cat >case/vendor/pconfigure/bootstrap.sh <<EOF
#!/bin/bash -e
mkdir -p bin
{ echo '#!/bin/bash'; cat src/pconfigure.bash; } > bin/pconfigure
chmod +x bin/pconfigure
echo "# bootstrapped" > Makefile
EOF
chmod +x case/vendor/pconfigure/bootstrap.sh

cat >case/vendor/pconfigure/Configfile <<EOF
LANGUAGES += bash

BINARIES  += pconfigure
SOURCES   += pconfigure.bash
TESTSRC   += vendored.bash
EOF

cat >case/Configfile <<EOF
BOOTSTRAP           = vendor/pconfigure

LANGUAGES          += c
LANGUAGES          += bash

TEST_SUITES        += network
DEFAULT_TEST_SUITE  = network

BINARIES           += top
SOURCES            += top.c
TESTSRC            += top-any.bash
EOF

refuses
grep -q "'vendor/pconfigure/' has 1 test and declares no test suite" out

# And the same one line fixes it there too.
cat >case/vendor/pconfigure/Configfile <<EOF
LANGUAGES   += bash

TEST_SUITES += network

BINARIES    += pconfigure
SOURCES     += pconfigure.bash
TESTSRC     += vendored.bash
EOF

accepts
# A project that bootstraps its own pconfigure keeps the Makefile make
# is run at in revision control, so the one pconfigure writes -- and
# with it the suite rule -- goes beside it under another name.
grep -q "^obj/check-suite-network-done: check/top/top-any.bash vendor/pconfigure/check/pconfigure/vendored.bash$" case/Makefile.pconfigure

exit 0
