#include "harness_start.bash"

# The ".." spelling of the same thing: "util/../main.c" stays inside
# the project, so it isn't refused, and it names src/main.c -- but as
# text it is a different path, and a different path was a second
# object and a second "main" on the link line.
mkdir -p src/util
echo 'int main(void) { return 0; }' > src/main.c
echo 'int helper(void) { return 0; }' > src/util/helper.c

cat >Configfile <<EOF
LANGUAGES += c

BINARIES  += main
SOURCES   += main.c
SOURCES   += util/helper.c
SOURCES   += util/../main.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
./bin/main

# And one object for it, not two, which is what the link failing was
# a symptom of.
test "$(find obj -name '*.o' -path '*main.c*' | wc -l)" = 1
