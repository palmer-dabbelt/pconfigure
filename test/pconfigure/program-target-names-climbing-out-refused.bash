#include "harness_start.bash"

# The other three kinds of program target name their outputs the same
# way BINARIES does -- the name pasted onto lib/, libexec/ or
# testexec/ and onto the install prefix -- so the same escape is open
# through each of them.  One loop rather than three files because it
# is one question asked of four commands, and an answer that differs
# between them is the bug.
mkdir -p proj/src
echo 'int f(void) { return 0; }' > proj/src/f.c
echo 'int main(void) { return 0; }' > proj/src/main.c

for line in "LIBRARIES += ../libevil.so|f.c" \
            "LIBRARIES += /tmp/libevil.so|f.c" \
            "LIBEXECS += ../../evil|main.c" \
            "TESTEXECS += ../evil|main.c"
do
    target="${line%|*}"
    source="${line#*|}"

    cat >proj/Configfile <<EOF
LANGUAGES += c

$target
SOURCES   += $source
EOF
    cat proj/Configfile
    rm -f proj/Makefile

    if (cd proj && $PTEST_BINARY $PCONFIGURE_ARGS) > out 2>&1
    then
        cat out
        echo "'$target' was accepted" >&2
        exit 1
    fi
    cat out

    grep -q "Configfile:3" out
    grep -q "it climbs out of the project\|it's an absolute path" out
    test ! -e proj/Makefile
done
