#include "harness_start.bash"

# "--phc ''" sets PHC to nothing.  A Configfile can't say that -- "PHC
# =" with no value is refused as unfinished, because only
# CROSS_COMPILE means anything when given nothing -- but the command
# line could, and the copy of every header then ran " -i src/x.h -o
# include/x.h": a shell looking for a program called "-i", and in the
# Makefile a recipe whose leading '-' make takes as "ignore errors".
# The refusal should come at the option, naming it, rather than from
# the header copy with advice about the include directory.
mkdir -p src
echo '#define X 1' > src/x.h

cat >Configfile <<'EOF2'
LANGUAGES += h
HEADERS   += x.h
SOURCES   += x.h
EOF2

if $PTEST_BINARY --phc '' > out 2>&1
then
    cat out
    exit 1
fi
cat out

test ! -e Makefile
grep -q "^args:1 " out
grep -q "PHC is given nothing" out
grep -q -- "give '--phc' the path" out
if grep -q "is a directory" out
then
    exit 1
fi

# The option with a tool after it is still fine, so it was the empty
# value that was refused and not the option.
phc="$(dirname "$PTEST_BINARY")/phc"
test -x "$phc"
$PTEST_BINARY --phc "$phc"
test -e Makefile
