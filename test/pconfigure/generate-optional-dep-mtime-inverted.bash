#include "harness_start.bash"

# What the '?' convention does NOT promise, pinned in the direction it
# really behaves, because an untested limitation is indistinguishable
# from a bug and the next reader will "fix" it.
#
# An optional input that arrives OLDER than the output regenerates
# nothing.  Once the file is there it is an ordinary prerequisite, and
# make's question about an ordinary prerequisite is "is it newer than the
# target", not "has it appeared" -- so a file that lands carrying a 2020
# timestamp sits beside an output generated today and make is right to
# call the output up to date.  Measured:
#
#     echo 42 > src/opt/answer.txt
#     touch -d 2020-01-01 src/opt/answer.txt
#     make
#     DEPS	gen.h
#     make: Nothing to be done for 'all'.
#     # and obj/proc/gen.h still holds "#define ANSWER 0"
#
# This state is UNREACHABLE for a mandatory input, which is why it is
# new: an absent mandatory prerequisite is a hard error, so there is no
# "before" for its arrival to be older than.  The '?' creates it by
# making absence legal.
#
# And it is reachable in practice rather than only in a test.  GNU tar
# restores mtimes, so a prebuilt toolchain unpacked into the directory a
# script is watching lands with the tarball's timestamps on it, which are
# whatever the machine that rolled the tarball had.
#
# Three things are asked here.  That the limitation is real, so that the
# documentation claiming otherwise cannot quietly come back.  That it is
# only about mtime -- a TOUCH of the same file, changing not one byte,
# regenerates immediately, so nothing is structurally un-watched and no
# reconfigure is needed to recover.  And that a second, newer change is
# heard normally afterwards, so the output is not wedged.
#
# Closing it would mean beating mtime, and mtime is all make has.  The
# cost is written up beside the limitation in doc/pconfigure.tex.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

GENERATE  += gen.h

BINARIES  += app
SOURCES   += app.c
EOF

cat >src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     echo "?src/opt/answer.txt" ;;
--generate) if test -f src/opt/answer.txt
            then echo "#define ANSWER $(cat src/opt/answer.txt)"
            else echo "#define ANSWER 0"
            fi ;;
esac
EOF
chmod +x src/gen.h.proc

cat >src/app.c <<'EOF'
  #include "gen.h"
  #include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
timeout 60 make $MAKE_ARGS > first.out 2>&1 || { cat first.out; exit 1; }
cat first.out
test "$(./bin/app)" = "0"

timeout 60 make $MAKE_ARGS > settled.out 2>&1 || { cat settled.out; exit 1; }
cat settled.out
grep -q "Nothing to be done" settled.out

##############################################################################
# The optional input arrives, dated before the output                        #
##############################################################################
sleep 2
mkdir -p src/opt
echo 42 > src/opt/answer.txt
touch -d 2020-01-01 src/opt/answer.txt

# The premise of the whole test: the arrived file really is older than
# the output that was generated without it.
test obj/proc/gen.h -nt src/opt/answer.txt

timeout 60 make $MAKE_ARGS > second.out 2>&1 || { cat second.out; exit 1; }
cat second.out

# The build does NOT fail.  That matters as much as the staleness: a
# prerequisite make cannot explain would stop here, and this one it can.
if grep -q "No rule to make target" second.out
then
    exit 1
fi

# And it did not regenerate, which is the limitation.  If a later change
# makes this regenerate, the limitation is closed and this test is the
# thing to delete -- along with the paragraph in doc/pconfigure.tex that
# records it, and the comment in gen_proc.c++ beside the filter.
if grep -q "^GEN	gen.h$" second.out
then
    exit 1
fi

grep -q "define ANSWER 0" obj/proc/gen.h
test "$(./bin/app)" = "0"

##############################################################################
# It is mtime and nothing else: a bare touch is enough                        #
##############################################################################
# This is what says the file is genuinely ON the rule rather than missing
# from it.  Nothing about the content changes here; only the timestamp
# does, and that alone regenerates -- so the recovery from the state
# above is a touch, not a reconfigure, and nothing is structurally
# un-watched.
sleep 2
touch src/opt/answer.txt

timeout 60 make $MAKE_ARGS > third.out 2>&1 || { cat third.out; exit 1; }
cat third.out
grep -q "^GEN	gen.h$" third.out
grep -q "define ANSWER 42" obj/proc/gen.h
test "$(./bin/app)" = "42"

timeout 60 make $MAKE_ARGS > fourth.out 2>&1 || { cat fourth.out; exit 1; }
cat fourth.out
grep -q "Nothing to be done" fourth.out

##############################################################################
# And an ordinary change afterwards is heard ordinarily                       #
##############################################################################
# The output is not wedged by having been stale once.
sleep 2
echo 7 > src/opt/answer.txt

timeout 60 make $MAKE_ARGS > fifth.out 2>&1 || { cat fifth.out; exit 1; }
cat fifth.out
grep -q "^GEN	gen.h$" fifth.out
grep -q "define ANSWER 7" obj/proc/gen.h
test "$(./bin/app)" = "7"

timeout 60 make $MAKE_ARGS > sixth.out 2>&1 || { cat sixth.out; exit 1; }
cat sixth.out
grep -q "Nothing to be done" sixth.out

exit 0
