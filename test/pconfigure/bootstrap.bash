#include "harness_start.bash"

# A project that vendors pconfigure and keeps the Makefile that builds
# it in revision control.  What's being checked here is the Makefile
# pconfigure writes rather than pconfigure's own bootstrap.sh, so the
# vendored tree is a stand-in: a bootstrap.sh, a Makefile it writes,
# and a pconfigure that is the real one wearing a different path.
#
# Both of them keep a log, because the whole question is what runs
# when.  A "make" that re-bootstraps or re-configures every time works
# and is useless.

here="$(pwd)"

mkdir -p src test/hello vendor/pconfigure

cat >vendor/pconfigure/pconfigure.in <<EOF
#!/bin/bash
echo ran >> "$here/configures"
exec "$PTEST_BINARY" "\$@"
EOF

cat >vendor/pconfigure/Makefile.in <<'EOF'
all: bin/pconfigure

bin/pconfigure: pconfigure.in
	mkdir -p bin
	cp pconfigure.in $@
	chmod +x $@
EOF

# The one thing a vendored pconfigure has to be able to do without a
# pconfigure: build itself and write down how to do it again.
cat >vendor/pconfigure/bootstrap.sh <<EOF
#!/bin/bash -e
echo ran >> "$here/bootstraps"
cp Makefile.in Makefile
make
EOF
chmod +x vendor/pconfigure/bootstrap.sh

cat >Configfile <<EOF
BOOTSTRAP   = vendor/pconfigure

LANGUAGES  += c
LANGUAGES  += bash

BINARIES   += hello
SOURCES    += hello.c
TESTSRC    += works.bash
EOF

cat >src/hello.c <<EOF
#include <stdio.h>
int main(void) { printf("hello\n"); return 0; }
EOF

cat >test/hello/works.bash <<EOF
test "\$(\$PTEST_BINARY)" = "hello"
EOF

##############################################################################
# What gets written                                                          #
##############################################################################
$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# The build itself moved next door, and what's left behind is the file
# that says how to get a pconfigure.
grep -q "^include Makefile.pconfigure$" Makefile
grep -q "^PCONFIGURE_SRCPATH  = vendor/pconfigure/$" Makefile
grep -q "^Makefile.pconfigure: | \$(PCONFIGURE)$" Makefile
grep -q "^\$(PCONFIGURE_SRCPATH)Makefile:$" Makefile
grep -q "bootstrap.sh$" Makefile

# The generated half is an ordinary pconfigure Makefile, and it is the
# only one of the two that knows anything about this project.
grep -q "^all:$" Makefile.pconfigure
grep -q "^bin/hello:" Makefile.pconfigure
if grep -q "hello" Makefile
then
    exit 1
fi

# Nothing has run either of them yet.
test ! -e bootstraps
test ! -e configures

##############################################################################
# A fresh checkout                                                           #
##############################################################################
# Which is the committed Makefile and the vendored source, and nothing
# else.  This is the state a stranger to the project arrives in.
cp Makefile Makefile.committed
rm -rf Makefile.pconfigure obj bin check
rm -rf vendor/pconfigure/Makefile vendor/pconfigure/bin

make $MAKE_ARGS

# It bootstrapped once, configured once, and built.
test "$(wc -l < bootstraps)" -eq 1
test "$(wc -l < configures)" -eq 1
test "$(./bin/hello)" = "hello"

# And it left the committed file alone, which is the point of writing
# it only when it would say something new.
cmp Makefile Makefile.committed

##############################################################################
# The second make                                                            #
##############################################################################
# A build that reconfigures every time is a build that rebuilds
# everything every time.  The vendored tree gets asked -- that's how
# an edit to pconfigure's own sources is noticed -- but asking is all
# it costs when the answer is no.
make $MAKE_ARGS > second.out 2>&1
cat second.out
test "$(wc -l < bootstraps)" -eq 1
test "$(wc -l < configures)" -eq 1

# And it says nothing about the vendored tree while it's at it.  A
# build that has nothing to do is a build that prints nothing, and
# four lines of somebody else's make on every one of them would be
# four lines nobody reads.
if grep -q "Entering directory" second.out
then
    exit 1
fi

make $MAKE_ARGS check
test -e check/hello/works.bash

make $MAKE_ARGS report > report.out
cat report.out
grep -q "^NRUN	1$" report.out
grep -q "PASS	hello/works.bash" report.out

test "$(wc -l < configures)" -eq 1

##############################################################################
# A new pconfigure                                                           #
##############################################################################
# Which is not a reason to configure again.  What a Makefile says is
# what the Configfiles said the last time somebody ran pconfigure, and
# a bootstrapping project is no different from any other one about
# that -- the vendored pconfigure being part of the build is not the
# build being allowed to decide when the build gets reconfigured.
sleep 1
touch vendor/pconfigure/pconfigure.in

make $MAKE_ARGS
test "$(wc -l < bootstraps)" -eq 1
test "$(wc -l < configures)" -eq 1

# Asking is what does it, and the pconfigure that runs is the vendored
# one rather than whatever the PATH happens to hold.
make $MAKE_ARGS reconfigure > reconfigure.out 2>&1
cat reconfigure.out
grep -q "^PCONFIGURE$" reconfigure.out
test "$(wc -l < configures)" -eq 2
test "$(wc -l < bootstraps)" -eq 1

##############################################################################
# Undoing a configure                                                        #
##############################################################################
# "make distclean" takes back what pconfigure wrote.  The committed
# Makefile isn't that: it's the file that was there first, and a tree
# it removed the Makefile from is a tree nobody can type "make" in
# any more.
make $MAKE_ARGS distclean
test -e Makefile
test ! -e Makefile.pconfigure
cmp Makefile Makefile.committed

make $MAKE_ARGS
test "$(./bin/hello)" = "hello"

exit 0
