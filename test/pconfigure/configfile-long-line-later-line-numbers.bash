#include "harness_start.bash"

# A diagnostic that names a Configfile line is only worth anything if
# it names the right one.  A long line earlier in the file is still one
# line, so the mistake on the line after it is on line 5 -- not on
# whatever line number a reader that took the long one in pieces would
# have counted up to by then.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

defines=""
for i in $(seq 1 300)
do
    defines="$defines -DDEFINE_NUMBER_$i"
done

cat >Configfile <<EOF
LANGUAGES   += c

BINARIES    += main
COMPILEOPTS += $defines
NOT_A_COMMAND += main.c
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    echo "a Configfile with an unknown command in it was accepted" >&2
    exit 1
fi
cat out

# The unknown command is what gets complained about, on its own line.
grep -q "Configfile:5: 'NOT_A_COMMAND" out
grep -q "NOT_A_COMMAND" out

# And nothing out of the middle of the long line is mistaken for a
# command of its own.
if grep -q "Unable to process -D" out
then
    exit 1
fi
