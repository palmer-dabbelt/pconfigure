#include "harness_start.bash"

# A project that vendors pconfigure and keeps the Makefile that builds
# it in revision control.  What's being checked here is the Makefile
# pconfigure writes rather than pconfigure's own bootstrap.sh, so the
# vendored tree is a stand-in: a Configfile that builds a pconfigure,
# a bootstrap.sh that can build one without a pconfigure, and a
# "pconfigure" that is the real one wearing a different path.
#
# Both of those keep a log, because the whole question is what runs
# when.  Bootstrapping is the one thing a build can't do for itself,
# and it should happen exactly once; configuring is something a person
# asks for, and should happen only when asked.

here="$(pwd)"

mkdir -p src test/hello vendor/pconfigure/src

cat >vendor/pconfigure/src/pconfigure.bash <<EOF
echo ran >> "$here/configures"
exec "$PTEST_BINARY" "\$@"
EOF

# An ordinary pconfigure project, which is the point: after the
# bootstrap this tree is built like any other subproject.
cat >vendor/pconfigure/Configfile <<EOF
LANGUAGES += bash

BINARIES  += pconfigure
SOURCES   += pconfigure.bash
EOF

# The one thing it has to be able to do without a pconfigure: produce
# one, and leave a Makefile behind saying it has been here.
cat >vendor/pconfigure/bootstrap.sh <<EOF
#!/bin/bash -e
echo ran >> "$here/bootstraps"
mkdir -p bin
{ echo '#!/bin/bash'; cat src/pconfigure.bash; } > bin/pconfigure
chmod +x bin/pconfigure
echo "# bootstrapped" > Makefile
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
grep -q "^Makefile.pconfigure: | \$(PCONFIGURE_SRCPATH)Makefile$" Makefile
grep -q "^\$(PCONFIGURE_SRCPATH)Makefile:$" Makefile
grep -q "bootstrap.sh$" Makefile

# And it cancels make's built-in rules, which the file it includes
# also does.  Saying it twice is the point: make looks for a rule to
# build a Makefile with before it has read the Makefile, so during the
# one phase that decides whether to run pconfigure, this is the only
# file that has been read.
grep -q "^\\.SUFFIXES:$" Makefile
grep -q "^%: %.sh$" Makefile
grep -q "^%:: RCS/%$" Makefile

# Nothing in it recurses into the vendored tree, because the vendored
# tree is a subproject: its Makefile is included, and the pconfigure
# in it is built out of the same graph as everything else.
if grep -q "\$(MAKE)" Makefile
then
    exit 1
fi
grep -q "^pconfigure_subdir_vendor_pconfigure ?= vendor/pconfigure/$" Makefile.pconfigure
grep -q "^include \$(pconfigure_subdir_vendor_pconfigure)Makefile$" Makefile.pconfigure

# The generated half is an ordinary pconfigure Makefile, and it is the
# only one of the two that knows anything about this project.
grep -q "^all:$" Makefile.pconfigure
grep -q "^bin/hello:" Makefile.pconfigure
if grep -q "hello" Makefile
then
    exit 1
fi

# The rule that runs pconfigure again lives in the committed file,
# where the pconfigure to run is named, and nowhere else.
grep -q "^reconfigure: \$(PCONFIGURE)$" Makefile
if grep -q "^reconfigure:" Makefile.pconfigure
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
# A file whose name make would otherwise take as a recipe for this
# one.  Buildroot keeps an arch/Config.in.sh next to its
# arch/Config.in, so this is not a hypothetical spelling; here it
# stands in for one, beside the file a fresh checkout has nothing but.
echo "the impostor" > Makefile.sh

cp Makefile Makefile.committed
rm -rf Makefile.pconfigure obj bin check
rm -rf vendor/pconfigure/Makefile vendor/pconfigure/bin vendor/pconfigure/obj

make $MAKE_ARGS

# It bootstrapped once, configured once, and built.
test "$(wc -l < bootstraps)" -eq 1
test "$(wc -l < configures)" -eq 1
test "$(./bin/hello)" = "hello"

# And it left the committed file alone, which is the point of writing
# it only when it would say something new.
cmp Makefile Makefile.committed

# Including its mode.  Without the cancellations make builds the
# committed Makefile out of the file beside it -- "cat Makefile.sh >
# Makefile; chmod a+x Makefile" -- and the configure that follows
# writes the contents back but not the bit, so the bytes alone would
# say nothing had happened.
test ! -x Makefile

# The Makefile bootstrap.sh left behind has been taken over by the
# configure that followed it: what is there now is a subproject's
# Makefile, written to be included from up here.
if grep -q "^# bootstrapped$" vendor/pconfigure/Makefile
then
    exit 1
fi
grep -q "^pconfigure_subdir_vendor_pconfigure ?=$" vendor/pconfigure/Makefile

##############################################################################
# The second make                                                            #
##############################################################################
# A build that reconfigures every time is a build that rebuilds
# everything every time, and a build that bootstraps every time is
# worse.
make $MAKE_ARGS > second.out 2>&1
cat second.out
test "$(wc -l < bootstraps)" -eq 1
test "$(wc -l < configures)" -eq 1

# And it says nothing about the vendored tree while it's at it.  There
# is no make being run in there to say anything: the tree's rules are
# in this make, which is the whole point of it being a subproject.
if grep -q "Entering directory" second.out
then
    exit 1
fi

# Nor does it rebuild the pconfigure in there, which is what makes the
# next section mean anything.
if grep -q "pconfigure$" second.out
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
# An edit to pconfigure's own sources                                        #
##############################################################################
# Which rebuilds it, because it is a subproject and that is what a
# subproject does -- and does not reconfigure anything, because a
# build doesn't decide when a tree gets reconfigured.
sleep 1
touch vendor/pconfigure/src/pconfigure.bash

make $MAKE_ARGS > edit.out 2>&1
cat edit.out
grep -q "pconfigure$" edit.out
if grep -q "Entering directory" edit.out
then
    exit 1
fi
test "$(wc -l < bootstraps)" -eq 1
test "$(wc -l < configures)" -eq 1

##############################################################################
# A configure with no pconfigure to do it with                               #
##############################################################################
# "make clean" deletes the vendored pconfigure along with everything
# else the build produced, since it is one of the things the build
# produced.  What must not happen then is a rule that runs it anyway:
# that is a tree which can no longer be built out of, and the way out
# of it is not written down anywhere.
make $MAKE_ARGS clean
test ! -x vendor/pconfigure/bin/pconfigure
rm -f Makefile.pconfigure

make $MAKE_ARGS > cleaned.out 2>&1
cat cleaned.out
test -e Makefile.pconfigure
test "$(./bin/hello)" = "hello"

# It built one for itself rather than failing, which is the second
# time this tree has had to.
test "$(wc -l < bootstraps)" -eq 2

##############################################################################
# Asking for a reconfigure                                                   #
##############################################################################
# The pconfigure that runs is the vendored one rather than whatever
# the PATH happens to hold, since the vendored one is the whole reason
# this project pinned a pconfigure at all.
make $MAKE_ARGS reconfigure > reconfigure.out 2>&1
cat reconfigure.out
grep -q "^PCONFIGURE$" reconfigure.out
test "$(wc -l < configures)" -eq 3
test "$(wc -l < bootstraps)" -eq 2

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
