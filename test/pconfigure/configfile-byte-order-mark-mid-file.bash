#include "harness_start.bash"

# A byte order mark is only a byte order mark at the very start of a
# file.  Anywhere else the same three bytes are an invisible character
# that somebody pasted in, and quietly dropping them there would make
# two commands that look identical on a terminal behave differently
# depending on which line they happen to be on.  So the second line
# here is still refused, and refused where it is.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

printf 'LANGUAGES += c\n\xef\xbb\xbfBINARIES += main\nSOURCES += main.c\n' \
    > Configfile

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    exit 1
fi
cat out
grep -q "Configfile:2" out
