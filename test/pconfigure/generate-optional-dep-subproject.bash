#include "harness_start.bash"

# An optional "--deps" line inside a subproject, which is where the
# convention has the most spellings to get right at once.  A
# subproject's paths are written through a make variable so that one
# Makefile means the right file whether make was run in the subproject
# or in a parent that pulled it in, and an optional line has to carry
# that variable in two different places: inside the "$(wildcard)" on
# the rule, and inside the sed expression that re-derives the fragment
# during the build -- where a literal '$' has to be written "$$" to
# survive make expanding the recipe before the shell sees it.  Getting
# either of those wrong produces a Makefile that is perfectly valid and
# names the wrong file, which is the failure mode that does not
# announce itself.
#
# generate-subproject.bash pins the mandatory-dep spelling.  This pins
# the optional one, and it pins the arrival through the parent's make,
# since the parent is where the directory the file arrives in is spelled
# with the subproject on the front.
#
# The script answers with one mandatory line and one optional line,
# which is the mixture the sed has to get right rather than either kind
# on its own.  The optional line is rewritten whole -- target, wildcard,
# path and all -- and then branched away from, because the expressions
# that handle the mandatory line would otherwise prepend the
# subproject's variable to a line already carrying it and wrap the
# result in a second target.  A test with only one kind of line in it
# cannot tell a working branch from a missing one.

mkdir -p sub/src

cat >Configfile <<EOF
SUBPROJECTS += sub
EOF

cat >sub/Configfile <<EOF
LANGUAGES += c

GENERATE  += gen.h

BINARIES  += app
SOURCES   += app.c
EOF

# An input it always reads, so that there is a mandatory line in the
# answer beside the optional one.
echo 1 > sub/src/base.txt

# Everything the script prints is relative to the project that owns it,
# optional lines included: the '?' marks the line, not the base.
cat >sub/src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     echo "src/base.txt"
            echo "?src/opt/answer.txt" ;;
--generate) echo "#define BASE $(cat src/base.txt)"
            if test -f src/opt/answer.txt
            then echo "#define ANSWER $(cat src/opt/answer.txt)"
            else echo "#define ANSWER 0"
            fi ;;
esac
EOF
chmod +x sub/src/gen.h.proc

cat >sub/src/app.c <<'EOF'
  #include "gen.h"
  #include <stdio.h>
int main(void) { printf("%d\n", ANSWER + 0 * BASE); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
cat sub/obj/Makefile.sub

timeout 60 make $MAKE_ARGS > first.out 2>&1 || { cat first.out; exit 1; }
cat first.out

if grep -q "No rule to make target" first.out
then
    exit 1
fi

test "$(./sub/bin/app)" = "0"

# Now the three spellings that bought that, each of which a future
# change could get wrong while still producing a valid Makefile.  The
# wildcard wraps a path spelled through the subproject's variable,
# rather than one spelled from the top of the tree, which is what makes
# the same line mean the right file from either directory -- and the
# mandatory line beside it is spelled the way it always was.
grep -qxF '$(pconfigure_subdir_sub)obj/proc/gen.h: $(pconfigure_subdir_sub)src/gen.h.proc $(pconfigure_subdir_sub)src/base.txt $(foreach f,$(wildcard $(pconfigure_subdir_sub)src/opt/answer.txt),$(if $(realpath $(f)),$(f),))' sub/obj/Makefile.sub

# The sed that re-derives the fragment writes "$$" where the fragment
# has to end up holding a "$", twice over: once for the target's
# variable and once for the path's.
grep -qF 's|^?[[:space:]]*\(.*\)|$$(pconfigure_subdir_sub)obj/proc/gen.h: $$(foreach f,$$(wildcard $$(pconfigure_subdir_sub)\1),$$(if $$(realpath $$(f)),$$(f),))|' sub/obj/Makefile.sub

# And the generate recipe brackets the "cd" and the script together and
# hangs the redirect off the group.  Without the brackets a "cd" that
# failed would reach the same "||" as a script that failed, and the
# recipe would delete the target because it could not find the
# directory to generate it in.
grep -q '(cd .*sub.* && src/gen.h.proc --generate) > .*obj/proc/gen.h.tmp && mv ' sub/obj/Makefile.sub

# The fragment the build wrote holds the variable rather than the
# directory, so the subproject's own make reads the same file and means
# its own files by it.
cat sub/obj/proc/gen.h.d
grep -qxF '$(pconfigure_subdir_sub)obj/proc/gen.h: $(foreach f,$(wildcard $(pconfigure_subdir_sub)src/opt/answer.txt),$(if $(realpath $(f)),$(f),))' sub/obj/proc/gen.h.d

# And the mandatory line in the same fragment came out the way it
# always did: one variable, one path, no wildcard.  This is the half
# that a missing branch in the sed would have mangled.
grep -q '^\$(pconfigure_subdir_sub)obj/proc/gen.h: \$(pconfigure_subdir_sub)src/base.txt$' sub/obj/proc/gen.h.d

timeout 60 make $MAKE_ARGS > settled.out 2>&1 || { cat settled.out; exit 1; }
cat settled.out
grep -q "Nothing to be done" settled.out

##############################################################################
# The optional input arrives, and the parent's make hears it                  #
##############################################################################
sleep 2
mkdir -p sub/src/opt
echo 42 > sub/src/opt/answer.txt

timeout 60 make $MAKE_ARGS > second.out 2>&1 || { cat second.out; exit 1; }
cat second.out

if grep -q "^PCONFIGURE$" second.out
then
    exit 1
fi

grep -q "^GEN	gen.h$" second.out
grep -q "define ANSWER 42" sub/obj/proc/gen.h
test "$(./sub/bin/app)" = "42"

timeout 60 make $MAKE_ARGS > third.out 2>&1 || { cat third.out; exit 1; }
cat third.out
grep -q "Nothing to be done" third.out

##############################################################################
# The mandatory input still works, with an optional one beside it             #
##############################################################################
# A branch in the sed that swallowed the rest of the script would leave
# the mandatory line out of the fragment, and nothing would notice until
# an input changed and nothing rebuilt.
sleep 2
echo 9 > sub/src/base.txt

timeout 60 make $MAKE_ARGS > base.out 2>&1 || { cat base.out; exit 1; }
cat base.out
grep -q "^GEN	gen.h$" base.out
grep -q "define BASE 9" sub/obj/proc/gen.h

timeout 60 make $MAKE_ARGS > base-settled.out 2>&1 || { cat base-settled.out; exit 1; }
cat base-settled.out
grep -q "Nothing to be done" base-settled.out

##############################################################################
# And the subproject still builds on its own                                 #
##############################################################################
# With the variable empty, which is the other half of what the two
# spellings are for.
cd sub
rm -rf obj bin
$PTEST_BINARY $PCONFIGURE_ARGS
timeout 60 make $MAKE_ARGS > own.out 2>&1 || { cat own.out; exit 1; }
cat own.out
grep -qxF 'obj/proc/gen.h: src/gen.h.proc src/base.txt $(foreach f,$(wildcard src/opt/answer.txt),$(if $(realpath $(f)),$(f),))' Makefile
test "$(./bin/app)" = "42"
cd ..

exit 0
