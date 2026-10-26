#include "harness_start.bash"

# phc copies a header to "<name>.tmp" beside where it goes and renames
# that into place -- after an "rm -f" of the ".tmp" name, to clear out
# what a failed copy left behind -- and the install into the prefix
# copies through "$@.tmp" too.  A project that has both "api.h" and
# "api.h.tmp" (a template, say) has handed the first header's copy the
# second header's path as its temporary: building or installing
# "api.h" removed "api.h.tmp", and "make install" finished with one of
# the two headers missing.  So the later of the two lines is refused.
mkdir -p src
echo 'int api;' > src/api.h
echo 'int api_template;' > src/template.h

cat >Configfile <<'EOF2'
LANGUAGES += h

HEADERS   += api.h.tmp
SOURCES   += template.h

HEADERS   += api.h
SOURCES   += api.h
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS >configure.out 2>&1
then
    cat configure.out
    exit 1
fi
cat configure.out

head -n1 configure.out | grep -qF "Configfile:6 'HEADERS += api.h'"
grep -qF "Configfile:3 'HEADERS += api.h.tmp'" configure.out
grep -qF "include/api.h.tmp'" configure.out

exit 0
