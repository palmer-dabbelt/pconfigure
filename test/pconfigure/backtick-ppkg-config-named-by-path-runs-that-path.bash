#include "harness_start.bash"

# The manual says the word "ppkg-config" in a backticked command is
# replaced with the ppkg-config pconfigure was told to use.  A
# Configfile that names one by its path -- an absolute path, or one
# in a directory of the project's own -- has written a path whose last
# component happens to be that word, not the word itself, and pasting
# a second absolute path into the middle of it names a file that does
# not exist.  The command then fails and the configure stops on it.

export PATH="$(dirname "$PTEST_BINARY"):$PATH"
tools="$(cd "$(dirname "$PTEST_BINARY")" && pwd)"

mkdir -p src pc

cat >pc/answer.pc <<'EOC'
Name: answer
Description: what the backticks print
Version: 1
Cflags: -DANSWER=42
EOC

cat >Configfile <<EOC
LANGUAGES   += c
COMPILEOPTS += \`PKG_CONFIG_PATH=$PWD/pc $tools/ppkg-config --cflags answer\`
BINARIES    += app
SOURCES     += main.c
EOC

cat >src/main.c <<'EOC'
#include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOC

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "42"
