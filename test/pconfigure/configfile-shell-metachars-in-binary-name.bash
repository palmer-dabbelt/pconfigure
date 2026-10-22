#include "harness_start.bash"

top="$tempdir"

# A '#', ':', '=' or quote are the characters a target name was first
# found to break the Makefile with, but they aren't the only ones.  A
# BINARIES name goes onto a rule line and bare into the recipes that
# build it, so the characters that end or redirect a shell command, and
# the rest of the ones make reads as its own syntax, break it as well:
#
#   ';'        "missing separator" -- make starts a recipe at the ';'
#   '|'        "No rule to make target 'bin/a'" -- order-only prereqs
#   '&'        shell Error 127 -- the rest runs as its own command
#   '(' ')'    shell Error 2 -- a subshell that doesn't parse
#   '<' '>'    shell Error 1 -- a redirection from or to nowhere
#   '\'        builds "bin/ab", not what was asked for
#   '$'        builds whatever "$b" expands to, not what was asked for
#
# Each is refused when the line is read, naming that line, before any
# Makefile is written.  None of these runs "make": the point is that
# pconfigure never gets far enough to write a rule make could misread.
n=0
for c in ';' '|' '&' '(' ')' '<' '>' '\' '$'
do
    n=$((n + 1))
    dir=$top/case$n
    mkdir -p $dir/src
    echo 'int main(void) { return 0; }' > $dir/src/main.c
    printf 'LANGUAGES   += c\nBINARIES    += a%sb\nSOURCES     += main.c\n' \
        "$c" > $dir/Configfile

    if (cd $dir && $PTEST_BINARY $PCONFIGURE_ARGS) > $dir.out 2>&1
    then
        cat $dir.out
        echo "a BINARIES with a '$c' in it was accepted" >&2
        exit 1
    fi
    cat $dir.out
    grep -q "Configfile:2" $dir.out
    grep -qF "BINARIES has a '$c' in it" $dir.out
    test ! -e $dir/Makefile
done
