#include "harness_start.bash"

# With no llvm-config on the PATH and no --optional, pllvm-config
# fails -- which is right -- but says nothing at all: llvm-config's
# own "command not found" is thrown away along with its version.
# ppkg-config, which the manual says pllvm-config behaves like, passes
# pkg-config's explanation through on stderr for a required package,
# and in a Configfile backtick that explanation is the only thing that
# says what is missing: pconfigure itself only knows the command
# exited with status 1.
llvm="$(dirname "$PTEST_BINARY")/pllvm-config"
test -x "$llvm"

mkdir emptybin
for tool in bash sed
do
    ln -s "$(command -v $tool)" emptybin/$tool
done

set +e
PATH="$(pwd)/emptybin" "$llvm" --cflags >missing.out 2>missing.err
status="$?"
set -e
cat missing.err
test "$status" != "0"
test ! -s missing.out
# The message is pllvm-config's own and names the tool, rather than
# the shell's "command not found" with a line number in a script the
# person configuring never wrote.
grep -q "^pllvm-config: .*llvm-config" missing.err

# --optional is still the way to ask for silence.
PATH="$(pwd)/emptybin" "$llvm" --optional --cflags >optional.out 2>optional.err
test ! -s optional.out
test ! -s optional.err

exit 0
