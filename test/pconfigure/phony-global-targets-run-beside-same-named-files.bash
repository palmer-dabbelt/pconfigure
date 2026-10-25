#include "harness_start.bash"

# The goals a generated Makefile answers to are names, not files, and
# each is declared .PHONY so that a stray file with the same name at
# the top of the tree -- a log somebody redirected to "install", a
# script called "report" -- doesn't turn the rule into a file that is
# already up to date and quietly does nothing.  This pins that down for
# each goal that is meant to do something every time it's asked: all,
# clean, cache-clean, install, uninstall, report, reconfigure,
# distclean and a suite's check-<name> and report-<name>.

mkdir -p src test/hello

cat >Configfile <<'EOF'
LANGUAGES   += c
LANGUAGES   += bash

TEST_SUITES += smoke

BINARIES    += hello
SOURCES     += hello.c
TESTSRC[smoke] += runs.bash
EOF

cat >src/hello.c <<'EOF'
int main(void) { return 0; }
EOF

cat >test/hello/runs.bash <<'EOF'
"$PTEST_BINARY"
EOF

$PTEST_BINARY $PCONFIGURE_ARGS

for name in all clean cache-clean install uninstall report reconfigure \
            distclean check-smoke report-smoke
do
    grep -q "^\.PHONY: $name$" Makefile
    echo "stray" > "$name"
done

# Each of these still does its job with the file sitting there, and
# the job is something that can be seen afterwards rather than just a
# make that exited 0.
make $MAKE_ARGS all
test -x bin/hello

make $MAKE_ARGS install DESTDIR="$tempdir/stage"
test -x stage/usr/local/bin/hello

make $MAKE_ARGS uninstall DESTDIR="$tempdir/stage"
test ! -e stage/usr/local/bin/hello

make $MAKE_ARGS check-smoke
test -f check/hello/runs.bash
make $MAKE_ARGS report-smoke > report-smoke.out
cat report-smoke.out
grep -q "PASS.*hello/runs.bash" report-smoke.out
make $MAKE_ARGS report > report.out
cat report.out
grep -q "PASS.*hello/runs.bash" report.out

# cache-clean takes an object nothing builds any more.
echo "orphan" > obj/orphan.o
make $MAKE_ARGS cache-clean
test ! -e obj/orphan.o
test -x bin/hello

make $MAKE_ARGS reconfigure > reconfigure.out
grep -q "PCONFIGURE" reconfigure.out

make $MAKE_ARGS clean
test ! -e bin/hello
test ! -e check/hello/runs.bash

# distclean goes last, since it takes the Makefile with it.
make $MAKE_ARGS
test -d obj
make $MAKE_ARGS distclean
test ! -e Makefile
test ! -e obj

# And none of it touched the stray files themselves.
for name in all clean cache-clean install uninstall report reconfigure \
            distclean check-smoke report-smoke
do
    test "$(cat "$name")" = "stray"
done

exit 0
