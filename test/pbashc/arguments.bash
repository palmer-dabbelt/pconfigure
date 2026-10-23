#include "tempdir.bash"

##############################################################################
# "-I" and "-D" as words of their own                                        #
##############################################################################
# The C languages take both spellings and a COMPILEOPTS is written
# without knowing which language will read it, so pbashc takes both
# too.  The glued spelling is checked alongside, since it is the one
# that worked before and it has to keep working.
mkdir -p inc glued
printf 'echo FROM\n' > inc/apart.bash
printf 'echo glued\n' > glued/together.bash
printf '#include "apart.bash"\n#include "together.bash"\n' > in.bash

$PTEST_BINARY -i in.bash -o out.bash -I inc -Iglued -D FROM=TO
cat out.bash
test "$(./out.bash)" = "TO
glued"

$PTEST_BINARY -i in.bash -o glued.bash -Iinc -Iglued -DFROM=TO
cmp out.bash glued.bash

##############################################################################
# One input                                                                  #
##############################################################################
# A second input used to replace the first, which is how "-I inc" lost
# its script: "inc" was a bare word, so it became the input.
printf 'echo other\n' > other.bash
if $PTEST_BINARY -i in.bash -o two.bash other.bash > two.out 2>&1
then
    exit 1
fi
cat two.out
grep -q "two input files, 'in\.bash' and 'other\.bash'" two.out
test ! -e two.bash

##############################################################################
# An input that is a directory                                               #
##############################################################################
# fopen() opens a directory and reading it gives back nothing, so this
# came out as a shebang and an empty script, and succeeded.
if $PTEST_BINARY -i inc -o dir.bash > dir.out 2>&1
then
    exit 1
fi
cat dir.out
grep -q "input 'inc' is a directory" dir.out
grep -q "write '-I inc'" dir.out
test ! -e dir.bash

##############################################################################
# A flag with nothing after it                                               #
##############################################################################
# At the end of the line there is nothing to take, and taking nothing
# quietly is how the empty search directory got in.
if $PTEST_BINARY -i in.bash -o end.bash -I > end.out 2>&1
then
    exit 1
fi
cat end.out
grep -q "'-I' needs something after it" end.out
test ! -e end.bash

exit 0
