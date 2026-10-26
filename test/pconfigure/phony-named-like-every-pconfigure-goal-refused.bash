#include "harness_start.bash"

# Every goal pconfigure writes into a Makefile on its own is a name a
# PHONY would merge into rather than stand beside: "make install"
# building whatever the PHONY named, "make all" picking up a name that
# was kept out of it on purpose, "make reconfigure" building before it
# configures.  A subproject's PHONY is refused the same way, even
# though at the top it lands under the subproject's directory: the
# subproject's Makefile is also the one somebody runs make on from
# inside it, where the name is as bare as it was written.

top="$tempdir"

for name in all cache-clean check clean distclean install reconfigure \
            report uninstall
do
    dir="$top/top-$name"
    mkdir -p "$dir/src"
    echo 'int main(void) { return 0; }' > "$dir/src/t.c"
    cat > "$dir/Configfile" <<EOC
LANGUAGES   += c
BINARIES    += t
SOURCES     += t.c
PHONY       += $name
TESTDEPS    += bin/t
EOC

    if (cd "$dir" && $PTEST_BINARY $PCONFIGURE_ARGS) > "$dir.out" 2>&1
    then
        cat "$dir.out"
        echo "PHONY += $name was accepted" >&2
        exit 1
    fi
    cat "$dir.out"
    grep -q "^./Configfile:4" "$dir.out"
    grep -qF "error: PHONY can't be called '$name'" "$dir.out"
    test ! -e "$dir/Makefile"

    dir="$top/sub-$name"
    mkdir -p "$dir/src" "$dir/sub/src"
    echo 'int main(void) { return 0; }' > "$dir/src/t.c"
    echo 'int main(void) { return 0; }' > "$dir/sub/src/u.c"
    cat > "$dir/Configfile" <<EOC
SUBPROJECTS += sub
LANGUAGES   += c
BINARIES    += t
SOURCES     += t.c
EOC
    cat > "$dir/sub/Configfile" <<EOC
LANGUAGES   += c
BINARIES    += u
SOURCES     += u.c
PHONY       += $name
TESTDEPS    += bin/u
EOC

    if (cd "$dir" && $PTEST_BINARY $PCONFIGURE_ARGS) > "$dir.out" 2>&1
    then
        cat "$dir.out"
        echo "PHONY += $name in a subproject was accepted" >&2
        exit 1
    fi
    cat "$dir.out"
    grep -q "^sub/Configfile:4" "$dir.out"
    grep -qF "error: PHONY can't be called '$name'" "$dir.out"
done
