#include "harness_start.bash"

# A HEADERS with no SOURCES under it is installed from the header
# directory as it is, and the one language whose job that is is
# implicit_h, which every project has without asking for it.  Any
# language that judges a target by the names of its sources had
# nothing to judge here, and said yes anyway: "h" and "c++" both
# claimed every such header, tied with implicit_h, and printed
#
#   WARNING: Multiple valid languages for ./Configfile:3 'HEADERS += ...'
#   selecting the first one: implicit_h
#
# on every configure, for every header installed this way.  That is
# the manual's own first HEADERS example in any project that also
# says "LANGUAGES += h" for its second, or in any C++ project at all.
# Nothing in it is ambiguous, and "implicit_h" isn't a language
# anybody can write in LANGUAGES, so it is a warning that can't be
# acted on -- which is the kind that teaches people to stop reading
# warnings.
#
# The "h" project installs its other header the second way, out of the
# source directory, which is the reason it has "h" at all.  The C++
# one needs nothing more than the one header.
mkdir -p h/src h/include
echo 'int impl(void);' > h/src/impl.h
cat >h/Configfile <<END
LANGUAGES += c
LANGUAGES += h
HEADERS   += api.h
HEADERS   += impl.h
SOURCES   += impl.h
END

mkdir -p cxx/include
cat >cxx/Configfile <<END
LANGUAGES += c++
HEADERS   += api.h
END

for dir in h cxx
do
    cd $dir
    echo 'int api(void);' > include/api.h

    $PTEST_BINARY $PCONFIGURE_ARGS >configure.out 2>&1
    cat configure.out
    if grep -q "Multiple valid languages" configure.out
    then
        exit 1
    fi

    # Still the header it was: read straight out of the header
    # directory, which is what implicit_h does and nothing else does,
    # and installed byte for byte.
    grep -q "^	@.*phc' -i include/api.h -o " Makefile
    make $MAKE_ARGS DESTDIR=$(pwd)/install install
    diff -u include/api.h install/usr/local/include/api.h

    cd ..
done

exit 0
