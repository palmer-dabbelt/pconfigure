#include "harness_start.bash"

# A target whose name is "." -- or a directory followed by "/." or
# "/.." -- is the output directory itself or a directory in it, not a
# file, so there is nothing make could build under that name.
# Normalizing turns "tools/." and "tools/main/.." into "tools", so the
# check has to be made of the name as written.  These spellings used to get
# through, and the first anyone heard of it was "mv: 'bin/..tmp' and
# 'bin/./..tmp' are the same file" from the middle of make; they are
# refused while configuring, naming the line.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

for command in BINARIES LIBEXECS TESTEXECS LIBRARIES
do
    for name in . ./ tools/. tools/./ tools/main/.. tools/main/../
    do
        rm -rf Makefile obj bin lib libexec testexec
        cat >Configfile <<EOF
LANGUAGES += c

$command += $name
SOURCES   += main.c
EOF

        if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
        then
            cat configure.out
            echo "$command += $name was accepted" >&2
            exit 1
        fi
        cat configure.out
        grep -qF "Configfile:3 '$command += $name'" configure.out
        grep -qF "names a directory" configure.out
    done
done
