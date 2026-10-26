#include "harness_start.bash"

# A language claims a source by its ending, and a file that is nothing
# but the ending -- a hidden file called ".c" -- still has it: the
# compiler takes ".c" as a C source like any other, and pconfigure
# already did when the same name was reached as "d/.c" or found behind
# an '#include ".h"'.  Spelled outright in a SOURCES line it was
# claimed by no language at all, and configure stopped with "Unable to
# find language" and a dump of its own state.  C++ claims its endings
# through the same question, so ".c++" gets asked here too, and the C
# file and the C++ file must each go to their own compiler.
mkdir -p src
echo 'int main(void) { return 5; }' > src/.c
cat >src/.c++ <<'EOT'
template<int N> struct k { static const int v = N; };
int main(void) { return k<6>::v; }
EOT
cat >Configfile <<'EOT'
LANGUAGES   += c
LANGUAGES   += c++

BINARIES    += app
SOURCES     += .c

BINARIES    += appxx
SOURCES     += .c++
EOT

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

set +e
./bin/app
got=$?
./bin/appxx
gotxx=$?
set -e
test "$got" = 5
test "$gotxx" = 6
