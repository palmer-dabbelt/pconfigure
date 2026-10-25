#include "harness_start.bash"

# Space at either end of a command-line Configfile line.  In a file
# that space is gone before the line is read; on the command line the
# line is read as typed, so a leading space is taken for an empty
# command name and a trailing one ends up inside the value -- a
# language called 'c ' that nobody has heard of.  Both are easy to type
# by building the word up in a shell variable.
mkdir -p src
echo 'int main(void) { return 0; }' > src/hello.c

cat >Configfile <<'EOF'
BINARIES += hello
SOURCES  += hello.c
EOF

for line in ' LANGUAGES += c' 'LANGUAGES += c ' '	LANGUAGES += c'
do
    rm -f Makefile
    if ! $PTEST_BINARY "$line" > out 2>&1
    then
        echo "refused: '$line'"
        cat out
        exit 1
    fi
    grep -q '^bin/hello:' Makefile
done

# And a word with nothing left once it's tidied -- empty, all space, or
# a comment -- is what a Configfile line like that is: nothing to do.
for line in '' '   ' '# LANGUAGES += c'
do
    rm -f Makefile
    if ! $PTEST_BINARY 'LANGUAGES += c' "$line" > out 2>&1
    then
        echo "refused: '$line'"
        cat out
        exit 1
    fi
    grep -q '^bin/hello:' Makefile
done
