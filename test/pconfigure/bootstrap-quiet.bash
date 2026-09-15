#include "harness_start.bash"

# What a build says while it bootstraps.  The rules that get a
# pconfigure out of a vendored tree are the only ones in a generated
# Makefile that run a program make did not build, and the recipe lines
# that do it carry a '+' so the jobserver reaches the sub-build.  A '+'
# is not a '@', though, and a line with one and not the other is a line
# make echoes -- so the first thing anybody saw of this project's build
# was the shell that checks whether a pconfigure is there:
#
#     test -x src/pconfigure/bin/pconfigure || (cd src/pconfigure/ && ./bootstrap.sh)
#
# printed on every single make, whether or not it went on to do
# anything.  Nothing else in a pconfigure build prints its own recipe;
# a build says "CC", "LD", "CP" and gets on with it.
#
# The stand-in vendored tree below is the one bootstrap.bash uses, for
# the same reason: what is being tested is the Makefile pconfigure
# writes, not pconfigure's own bootstrap.sh, so the tree only has to be
# shaped like one that bootstraps.

here="$(pwd)"

mkdir -p src vendor/pconfigure/src

cat >vendor/pconfigure/src/pconfigure.bash <<EOF
exec "$PTEST_BINARY" "\$@"
EOF

cat >vendor/pconfigure/Configfile <<EOF
LANGUAGES += bash

BINARIES  += pconfigure
SOURCES   += pconfigure.bash
EOF

# It says it ran, because a bootstrap that did not happen and a
# bootstrap that happened quietly look the same from out here.
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

BINARIES   += hello
SOURCES    += hello.c
EOF

cat >src/hello.c <<EOF
#include <stdio.h>
int main(void) { printf("hello\n"); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

##############################################################################
# The '+' is still on both of them                                           #
##############################################################################
# Checked here as text because nothing a test can run will tell the
# difference any more.  GNU make 4.4 hands the jobserver over through a
# named fifo whose path travels in MAKEFLAGS, which a recipe inherits
# whether or not its line was marked recursive -- so a sub-build gets
# its parallelism either way, and only a make old enough to pass the
# jobserver as file descriptors still fails without the '+'.  Making
# the test depend on that would be a test that stops testing anything
# the day the host's make is upgraded, which is worse than a grep that
# says plainly what it is looking at.
grep -q '^	@+test -x \$(PCONFIGURE) ||' Makefile
grep -q '^	@+cd \$(PCONFIGURE_SRCPATH) && \./bootstrap\.sh$' Makefile

##############################################################################
# A fresh checkout, which is where it has something to say               #
##############################################################################
cp Makefile Makefile.committed
rm -rf Makefile.pconfigure obj bin check
rm -rf vendor/pconfigure/Makefile vendor/pconfigure/bin vendor/pconfigure/obj

make $MAKE_ARGS > fresh.out 2>&1
cat fresh.out

# It bootstrapped, and it said so -- in the same shape as every other
# line a build prints, a word and the thing it is being done to.  A
# bootstrap is half a minute of somebody else's build arriving in the
# middle of this one, and a build that goes silent for that long and
# then prints a wall of "CC" lines from a project nobody asked about is
# harder to read than one that says whose they are.
test "$(wc -l < bootstraps)" -eq 1
grep -q "^BOOTSTRAP	vendor/pconfigure/$" fresh.out

# Once, though.  Both rules can announce it and only one of them
# bootstraps: the tree's Makefile is what says a bootstrap has already
# happened, and the check for the binary is there for the other case,
# where "make clean" took it away.
test "$(grep -c '^BOOTSTRAP' fresh.out)" -eq 1

# And what it did not do is read its own recipe out loud.
if grep -q "test -x" fresh.out
then
    exit 1
fi
if grep -q "bootstrap.sh" fresh.out
then
    exit 1
fi

##############################################################################
# Every make after that                                                      #
##############################################################################
# The rule still runs -- Makefile.pconfigure is a file make remakes
# before it reads it, so the check for a pconfigure happens on every
# single build.  Finding one is the ordinary case, and the ordinary
# case has nothing to report.
make $MAKE_ARGS > again.out 2>&1
cat again.out

test "$(wc -l < bootstraps)" -eq 1

# Said positively first, because the three checks below are all
# negative and an empty file satisfies every one of them.  A make that
# printed nothing at all -- through a harness that stopped capturing,
# or a redirect that went somewhere else -- would look exactly like a
# make that was quiet because there was nothing to do.  This is the
# line that tells the two apart.
grep -q "Nothing to be done" again.out

if grep -q "test -x" again.out
then
    exit 1
fi
if grep -q "bootstrap.sh" again.out
then
    exit 1
fi
if grep -q "^BOOTSTRAP" again.out
then
    exit 1
fi

##############################################################################
# A pconfigure the build removed                                             #
##############################################################################
# "make clean" deletes the vendored pconfigure, because the build
# produced it.  The tree's Makefile survives, so the rule that
# bootstraps has nothing to do and the check for the binary is what
# notices -- the other half of the pair, announcing it from inside the
# shell that decides.
make $MAKE_ARGS clean
test ! -x vendor/pconfigure/bin/pconfigure
rm -f Makefile.pconfigure

make $MAKE_ARGS > cleaned.out 2>&1
cat cleaned.out

test "$(wc -l < bootstraps)" -eq 2
grep -q "^BOOTSTRAP	vendor/pconfigure/$" cleaned.out
test "$(grep -c '^BOOTSTRAP' cleaned.out)" -eq 1
if grep -q "test -x" cleaned.out
then
    exit 1
fi

# None of which was worth rewriting the committed Makefile over.
cmp Makefile Makefile.committed

exit 0
