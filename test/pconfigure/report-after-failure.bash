#include "harness_start.bash"

mkdir -p src test/suite

# stale-report.bash covers a scoring that FAILED: ptest ran, said NFAIL
# 1, exited nonzero, and the recipe's "||" arm deleted the report on the
# way out.  This covers the scoring that neither passed nor failed,
# which is how an overnight run actually tends to end -- somebody hits
# ^C, a job timeout fires, the machine goes away.  The recipe's shell
# dies where it stands, no arm runs, and before the fix "$@" had never
# been touched at all: the PREVIOUS run's report was still sitting there
# with the PREVIOUS run's mtime, which is indistinguishable from a
# report of the run that was just interrupted.  That is the one state a
# reader cannot be expected to catch, because every signal they have --
# the file is there, it is well-formed, it is not older than the stamp
# -- says it is current.
#
# make's own interrupt handling does not cover this and it is worth
# saying why, because it looks as though it should: make deletes the
# target of the recipe it was running only when that recipe had changed
# the file, and this recipe writes "$@.tmp" until its last step.  There
# is nothing for make to decide to delete.  A SIGKILL gets no handler in
# either process.
#
# Two suites, because the per-suite reports are the same recipe again
# and have gone out of step with the project-wide pair before.
cat >Configfile <<EOF
LANGUAGES           += c
LANGUAGES           += bash

TEST_SUITES         += smoke

TEST_SUITES         += overnight

BINARIES            += suite
SOURCES             += suite.c
TESTSRC[smoke]      += loud.bash
TESTSRC[overnight]  += quiet.bash
EOF

cat >src/suite.c <<EOF
int main(void) { return 0; }
EOF

for t in loud quiet
do
    echo true > "test/suite/$t.bash"
done

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# A killed scorer cannot be arranged by killing make at a guessed
# moment: ptest scores a two-test project in milliseconds, so a sleep
# long enough to be reliable is long enough for the scoring to have
# finished, and one short enough to land inside it is a race that will
# pass for the wrong reason about as often as it fails.
#
# So the scorer is parked rather than raced.  "$@.tmp" is made a FIFO,
# and the recipe's "> $@.tmp" then blocks in open(2) until a reader
# turns up, which nothing here ever does.  That is deterministic and it
# is also precisely the right place: open(2) happens after the "rm -f
# $@" this test is about and before ptest has been exec'd, so the
# process group sits in the window the fix creates for as long as we
# like.
#
# "set -m" is what makes the kill possible.  Without job control a
# background job shares this script's process group, so "kill -9 -$!"
# would kill the test; with it, each job gets a group of its own whose
# id is the job's pid, and killing that group takes make and the
# recipe's shell together.  Killing make alone would leave the shell
# blocked on the FIFO forever -- one leaked process per run of this
# test, which is not a thing a suite should do.
set -m

# $1 the make target to ask for, $2 the report file it builds, $3 the
# stamp whose mtime makes it out of date.
killed_scoring_leaves_no_report() {
    local target="$1" report="$2" stamp="$3"

    test -e "$report"

    # The sleep is for mtime granularity, which is a second on plenty
    # of filesystems: the stamp has to come out newer than the report
    # rather than merely not older, or make has nothing to do and the
    # recipe never runs.
    sleep 2s
    touch "$stamp"

    rm -f "$report.tmp"
    mkfifo "$report.tmp"

    make $MAKE_ARGS "$target" > "killed-$target.out" 2>&1 &
    local mkpid=$!

    # Bounded, because a test that hangs tells nobody anything.  The
    # loop is an optimisation and not the assertion: before the fix it
    # runs out, which is correct of it, and the assertion below is what
    # fails.
    local i=0
    while test "$i" -lt 20
    do
        if test ! -e "$report"
        then
            break
        fi
        sleep 1
        i=$((i + 1))
    done

    # The report is gone while the scoring is still in flight, so there
    # is no instant at which a kill could leave the old one behind.
    test ! -e "$report"

    kill -9 "-$mkpid" || true
    wait "$mkpid" || true

    # And it stays gone: nothing in that recipe ran to put it back, and
    # nothing was going to.
    test ! -e "$report"

    # The FIFO would park the next scoring too, which is this test's
    # doing and not the tree's.
    rm -f "$report.tmp"
}

##############################################################################
# A passing run writes the reports                                           #
##############################################################################
# The green state every case below starts from: four files on disk, all
# of them saying NFAIL 0 about a run that really did pass.
make $MAKE_ARGS check
make $MAKE_ARGS report > green.out
cat green.out
grep -q "^NFAIL	0$" green.out
test -e obj/check-report
test -e obj/check-report-quiet

make $MAKE_ARGS check-smoke
make $MAKE_ARGS report-smoke > green-smoke.out
cat green-smoke.out
grep -q "^NFAIL	0$" green-smoke.out
test -e obj/check-suite-smoke-report
test -e obj/check-suite-smoke-report-quiet

##############################################################################
# A killed scoring takes the report with it                                  #
##############################################################################
# The loud project-wide report first, because it is the one a person
# reads.
killed_scoring_leaves_no_report report obj/check-report obj/check-all-done

# Then the quiet one, which is the worse half: ptest --quiet prints
# nothing when nothing failed, so a passing quiet report is an empty
# file and a stale one is byte for byte what a fresh one would have
# been.  Existence is the whole of what a reader has to go on, which is
# exactly why it must not exist while the answer is unknown.
killed_scoring_leaves_no_report check obj/check-report-quiet \
    obj/check-all-done

# And a suite's pair, which is the same recipe written out again per
# suite and is therefore capable of being wrong on its own.
killed_scoring_leaves_no_report report-smoke \
    obj/check-suite-smoke-report obj/check-suite-smoke-done
killed_scoring_leaves_no_report check-smoke \
    obj/check-suite-smoke-report-quiet obj/check-suite-smoke-done

# The suite nobody interrupted keeps its reports.  Deleting up front is
# per-report and per-run, not a tree-wide amnesty.
make $MAKE_ARGS check-overnight
make $MAKE_ARGS report-overnight > green-overnight.out
cat green-overnight.out
grep -q "^NFAIL	0$" green-overnight.out
test -e obj/check-suite-overnight-report
test -e obj/check-suite-overnight-report-quiet

##############################################################################
# Asking again re-scores                                                     #
##############################################################################
# The other half of "a report exists if and only if the last scoring of
# it passed": a tree that has lost its reports to an interruption is not
# a tree that has lost them for good.  The results are still in the
# tarballs under check/, so the next ask re-scores them without running
# a single test again.
make $MAKE_ARGS report > green-again.out
cat green-again.out
grep -q "^NFAIL	0$" green-again.out
test -e obj/check-report
grep -q "^NFAIL	0$" obj/check-report

make $MAKE_ARGS check
test -e obj/check-report-quiet
test ! -s obj/check-report-quiet

make $MAKE_ARGS report-smoke > green-smoke-again.out
cat green-smoke-again.out
grep -q "^NFAIL	0$" green-smoke-again.out
test -e obj/check-suite-smoke-report

make $MAKE_ARGS check-smoke
test -e obj/check-suite-smoke-report-quiet

##############################################################################
# A scoring that is not interrupted still writes its report                  #
##############################################################################
# The up-front delete is a window, not a policy: the report comes back
# at the end of a scoring that got to finish, and a second ask with
# nothing out of date does not disturb it.
sleep 2s
touch obj/check-all-done
make $MAKE_ARGS report > green-third.out
cat green-third.out
grep -q "^NFAIL	0$" green-third.out
test -e obj/check-report
cp obj/check-report kept-report

make $MAKE_ARGS report > green-fourth.out
cmp obj/check-report kept-report

exit 0
