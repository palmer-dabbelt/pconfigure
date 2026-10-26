#include "harness_start.bash"

# Each watched name with a lone parenthesis works on its own, but two
# of them on one rule line are read together: make takes a word with a
# '(' in it, followed later on the line by a word ending in ')', as an
# archive group -- "lib(a.o b.o)" -- and turns 'notes(1.txt' and
# 'Configfile.more)' into members of an archive called 'notes' that
# nothing makes.  Both have to be watched, so the one with the '(' can't
# share a rule line with the other.

mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c
echo 1 > 'notes(1.txt'
echo '# more' > 'Configfile.more)'
cat >Configfile <<'EOC'
AUTORECONFIGURE  = true
CONFIG_DEPS     += notes(1.txt
CONFIG          += more)
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
EOC

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

for f in 'notes(1.txt' 'Configfile.more)'
do
    make $MAKE_ARGS > first.log 2>&1 || { cat first.log; exit 1; }
    cat first.log
    if grep -q PCONFIGURE first.log
    then
        exit 1
    fi

    sleep 1
    echo '# 2' >> "$f"
    make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
    cat second.log
    grep -q PCONFIGURE second.log
done
