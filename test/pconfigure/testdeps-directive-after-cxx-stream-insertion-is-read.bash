#include "harness_start.bash"

# A heredoc is a shell's, and only a script's lines are read with
# them in mind.  In a C++ test a "<<" is an insertion into a stream,
# and 'std::cout << "x"' has the shape of a heredoc that ends at a
# line saying "x".  Read as one, everything after it is heredoc body
# and a "#pconfigure" further down never takes effect, so the test
# runs without the program it said it needed.
mkdir -p src test/main

cat >Configfile <<'EOF'
LANGUAGES += c++

TESTEXECS += tool
SOURCES   += tool.c++

BINARIES  += main
SOURCES   += main.c++
TESTSRC   += t.c++
EOF

echo 'int main(void) { return 0; }' > src/tool.c++
echo 'int main(void) { return 0; }' > src/main.c++

# Written with printf rather than a heredoc, since a '#' in the first
# column of this file is read by the pconfigure that builds it.  The
# directive is one only pconfigure reads: what this looks at is the
# Makefile, and the test is never compiled.
{
    printf '%s\n' '#include <iostream>'
    printf '%s\n' 'static void say(void) { std::cout << "x"; }'
    printf '%s\n' '#pconfigure TESTDEPS += testexec/tool'
} > test/main/t.c++

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

grep -q "^check/main/t.c++:.* testexec/tool" Makefile
