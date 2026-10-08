#include "harness_start.bash"

# A test that cannot run says so and exits 0: there is nothing wrong
# with the tree, so a FAIL would be a lie about it.  Scored as a pass
# that makes "ran and succeeded" indistinguishable from "did not run",
# and it is the second one that goes wrong quietly -- a missing cross
# compiler or an empty generated payload takes a third of a suite out
# of service and the report goes on saying everything passed.
#
# These cases go through the real runner rather than hand-building a
# result tarball the way check-result.bash does, because two separate
# things have to hold and only one of them is the report's.  The skip
# sentence is written to stderr, by convention and by every helper in
# this tree that writes one, and whether stderr reaches the tarball at
# all is ptest's own ">&" redirect on the line that runs the test.  A
# report tested against a tarball somebody wrote by hand would pass
# with that redirect broken.

# Runs one test under ptest and leaves its result where a report can
# find it.  The script is read from stdin so each case below reads as
# the test it is describing.
run() {
    local name="$1"

    rm -rf "$name"
    mkdir -p "$name/check"
    cat >"$name/t.bash"
    chmod +x "$name/t.bash"

    "$PTEST_BINARY" --test "$name/t.bash" --out "$name/check/t.bash"
}

# One case's report.  Scoped to that case's own check directory, so
# every count below is about exactly the one test it set up.
report() {
    local name="$1"

    "$PTEST_BINARY" --no-check-make-check --check-dir "$name/check"
}

##############################################################################
# A skip is not a pass                                                       #
##############################################################################
run skipped <<'EOF'
#!/bin/bash
echo "SKIP: no AArch64 Linux cross compiler" >&2
exit 0
EOF

report skipped > skipped.out
cat skipped.out

grep -q "^NRUN	1$" skipped.out
grep -q "^NSKIP	1$" skipped.out

# The whole point: the one test that did not run is not in NPASS.  A
# skip counted there as well as in NSKIP would make the numbers add up
# to more than NRUN and would still let a suite report full marks for
# a run that executed nothing.
grep -q "^NPASS	0$" skipped.out
if grep -q "PASS	skipped/t.bash" skipped.out
then
    exit 1
fi

# And the reason, on the line that names the test.  It was reachable
# before only by untarring the result by hand, which is not something
# anybody does to a test that is reporting success -- so the one
# sentence explaining why a third of a suite did nothing reached no
# terminal at all.  The report already has the line in front of it.
grep -q "SKIP	skipped/t.bash	no AArch64 Linux cross compiler$" skipped.out

# A skip does not fail the run.  Nothing is wrong, and a report that
# exited nonzero here would stop "make check" on a machine that is
# merely missing a tool.  Which skips are acceptable is a question
# about a particular suite on a particular machine, and ptest has not
# been told the answer: it reports the count and lets the caller
# decide.
if ! report skipped > /dev/null
then
    exit 1
fi

##############################################################################
# A skip found half way through is still a skip                              #
##############################################################################
# Not every test knows up front.  A VMM that reports no hypervisor
# backend does so when it is run, which can be after an earlier stage
# of the same test has already printed its own success -- and a test
# that got half way and then found out it could not finish has still
# not run.  So the sentence is looked for anywhere in the output
# rather than only on the first line, which is the cheaper question
# and the wrong one.
run late <<'EOF'
#!/bin/bash
echo "PASS:  the stage that could run"
echo "SKIP: no hypervisor backend implemented on this platform" >&2
exit 0
EOF

report late > late.out
cat late.out

grep -q "^NSKIP	1$" late.out
grep -q "^NPASS	0$" late.out

##############################################################################
# Saying the word is not the same as saying so                               #
##############################################################################
# The sentence is a line of its own beginning with "SKIP:", not a
# substring of the output.  A test is free to mention the convention
# in passing -- the ones that audit other tests' results do exactly
# that -- and reading that as a verdict would be the same wrong
# answer pointing the other way: a test that ran and passed, reported
# as one that never ran.
run mentions <<'EOF'
#!/bin/bash
echo "checked three cases and none of them had to SKIP: all three ran"
exit 0
EOF

report mentions > mentions.out
cat mentions.out

grep -q "^NPASS	1$" mentions.out
grep -q "^NSKIP	0$" mentions.out

##############################################################################
# A skip does not excuse a failure                                           #
##############################################################################
# The exit status still decides.  A test that announced a skip and
# then fell over has failed, and scoring it on what it printed would
# hand every test a way to opt out of being judged.
run broken <<'EOF'
#!/bin/bash
echo "SKIP: this one says it skipped and then falls over" >&2
exit 1
EOF

if report broken > broken.out
then
    exit 1
fi
cat broken.out

grep -q "FAIL	broken/t.bash" broken.out
grep -q "^NSKIP	0$" broken.out

##############################################################################
# A result from before any of this still reports                             #
##############################################################################
# The report reads a member that a tarball is not guaranteed to have:
# a result written by hand holds only the exit status, and so does one
# left by a ptest that predates this.  Neither is a skip and neither
# is an error -- the exit status is still right there -- so the
# question has to be asked in a way that takes "no output at all" for
# an answer.
rm -rf bare
mkdir -p bare/check bare/build
echo "0" > bare/build/ptest__return
(cd bare/build && tar -c ptest__return) > bare/check/t.bash

report bare > bare.out
cat bare.out

grep -q "^NRUN	1$" bare.out
grep -q "^NPASS	1$" bare.out
grep -q "^NSKIP	0$" bare.out

##############################################################################
# The quiet report                                                           #
##############################################################################
# "make check" is "ptest --quiet", which prints a line only for a
# result somebody has to act on.  A skip storm is one of those, and
# one line is all it takes to see it -- which is the difference
# between a suite that stopped running a third of itself and a suite
# that passed.
"$PTEST_BINARY" --quiet --no-check-make-check --check-dir skipped/check \
    > quiet.out
cat quiet.out

grep -q "^NSKIP	1$" quiet.out

# Per-test lines are still suppressed, skips included.  There were 470
# of them in this tree's glade-vm suite once; printing each one would
# bury the FAILs that quiet mode exists to show.
if grep -q "skipped/t.bash" quiet.out
then
    exit 1
fi

# And a green run's quiet report is still an empty file.  That is
# load-bearing rather than cosmetic: "make check" writes it to disk
# and stale-report.bash asserts its size, so a suite with nothing to
# excuse has to go on saying nothing at all.
"$PTEST_BINARY" --quiet --no-check-make-check --check-dir mentions/check \
    > quiet-green.out
cat quiet-green.out
test ! -s quiet-green.out

exit 0
