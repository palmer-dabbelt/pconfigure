#include "harness_start.bash"

# A command in backticks is put into the line the way a shell would
# put it there: what it printed, with its line breaks read as the
# whitespace between words.  pkg-config and the *-config scripts it
# replaced print their flags however they like, and one that puts each
# flag on its own line is still printing several flags -- gluing the
# last character of one line onto the first of the next turns "-DA" and
# "-DB" into a single "-DA-DB" that defines neither.  A blank line
# and an indented one are in there too, since to a shell those are
# still only the space between two words, and one space is all that
# should come out for them.  So is a flag far longer than any line
# buffer, which has to stay one word however it's read: line breaks
# separate words, the size of a read doesn't.
long_name="FROM_A_LONG_LINE_$(printf 'x%.0s' $(seq 1 2000))"
mkdir -p src
cat >src/main.c <<EOF
#if !defined(FROM_LINE_ONE) || !defined(FROM_LINE_TWO)
#error a flag printed on its own line went missing
#endif
#ifndef $long_name
#error a very long flag was split
#endif
int main(void) { return 0; }
EOF

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += main
COMPILEOPTS += `printf -- '-DFROM_LINE_ONE\n\n  -DFROM_LINE_TWO\n'`
COMPILEOPTS += `awk 'BEGIN { printf "-DFROM_A_LONG_LINE_"; for (i = 0; i < 2000; i++) printf "x"; print "" }'`
SOURCES     += main.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

if grep -q -- "-DFROM_LINE_ONE-DFROM_LINE_TWO" Makefile
then
    echo "two lines of backtick output were glued into one word" >&2
    exit 1
fi
grep -q -- "-DFROM_LINE_ONE -DFROM_LINE_TWO" Makefile
grep -q -- "-D$long_name" Makefile

make $MAKE_ARGS
./bin/main
