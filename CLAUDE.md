# Working in this tree

## Git

Work directly on `master`, in this checkout.  No worktrees, no feature
branches: the history here is linear and that's on purpose.

Commit as you go, and make the commits as small as is reasonable.  A
change that lands in one commit because it was written in one sitting
is a change nobody can review or bisect a piece at a time.  The test
of "small enough" is whether the commit does one thing that can be
described without an "and": plumbing that nothing reads yet is its own
commit, the thing that reads it is another, and the diagnostics for
getting it wrong are a third.

Every commit builds and passes `make check` on its own.  That's what
makes the small commits worth anything -- a bisect that lands on a
commit which doesn't build has to skip it, and a series where only the
last commit works is one commit wearing several hats.

Never push, force-push or merge without being asked.

## Commit messages

    <component>: <what it does, imperative, no trailing period>

    <why, in prose>

`pconfigure:` for the program and its tests, `doc:` for the manual.
The summary says what the change does rather than what it touches.

The body is prose, and it is about *why*: what was wrong before, what
was considered and rejected, what the change deliberately doesn't
promise.  What the diff does is in the diff.  Look at `git log` before
writing one -- the register is worth matching.

## What goes in a commit

Tests ship with the code they test, in the same commit.  A new test
under `test/pconfigure/` has to be added to `Configfiles/main` or
nothing runs it.

Manual changes go in their own `doc:` commit, after the commits that
made them true.

Don't reference a thing that doesn't exist yet.  If a comment in an
earlier commit wants to name a command a later commit adds, write the
comment so it stands on its own instead.

## Building and testing

    ./bin/pconfigure     # regenerate the Makefile after Configfile changes
    make
    make check           # runs the tests; fails if any of them did
    make report          # says which ones, and how they went

`make check` builds every test result and then reports, so it fails
when a test fails.  An individual test's check target succeeds either
way -- a test that failed is a test that finished.  `bin/ptest
--no-check-make-check` prints the report without asking make anything,
which is what to use when the tree is mid-change.

Results are tarballs under `check/`, one per test, holding whatever the
test left in `$PTEST_TMPDIR` plus its exit status in `ptest__return`.
Stale ones from a test that has since been deleted stay there and keep
getting counted, so clear them out rather than trusting the total.

## Code

C++ that reads like the C++ already there.  The comments are prose,
they explain why rather than what, and there are a lot of them -- that
is the house style, not an accident.  A fatal error says what was
wrong, points at the `Configfile` line that caused it, and says what
to write instead.

A check target is emitted separately by `languages/bash.c++` and
`languages/cxx.c++`.  They are two copies of the same handful of
lines, so a change to one almost always belongs in the other, and a
test that only exercises one of them will not notice.
