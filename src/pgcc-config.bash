# pgcc-config is meant to be run inside a Configfile backtick, where
# everything it prints on stdout becomes compiler flags.  So stdout is
# only ever the answer: the usage and every reason for giving up go to
# stderr, where they're a diagnostic rather than words of a compile
# command.  The usage's heredoc delimiter is quoted because the text
# mentions `program -dumpversion` as prose, not as something to run.
#
# Anything past the version means the caller wanted the compare mode,
# and that mode needs both a test and a flag.  A test whose flag is
# missing -- forgotten, or a variable that expanded to nothing -- used
# to fall through into the search mode below, which answers "${CC}" on
# stdout when it finds nothing, and a backtick would paste that make
# variable into the compile flags.  Refusing with the usage says what
# to write instead.
if [[ "$1" == "" || "$2" == "" ]] || \
   [[ "$#" -gt 2 && ( "$3" == "" || "$4" == "" ) ]]
then
    cat >&2 <<'EOF'
pgcc-config <program> <version> [test] [flag]

  If [test] and [flag] are passed, then flag is returned IFF the test
    passes on `program -dumpversion`.
  Otherwise, a patch version is found that matches the supplied
    version.
EOF
    exit 1
fi

program="$1"
version="$2"
test="$3"
flag="$4"

if [[ "$test" != "" && "$flag" != "" ]]
then
    # The program's own answer is captured before it is trimmed, because
    # a pipeline's status is the last command's: through "| cut" a
    # compiler that isn't installed, or one that refuses -dumpversion,
    # looks like a successful run that printed nothing.  Either way there
    # is no version to compare, and saying so here keeps the refusal of
    # an unparseable version below from blaming the version of a
    # program that never answered.  The program's own stderr is left
    # alone so whatever it (or the shell, for a missing one) said is
    # right above ours.
    if ! rawversion="$($program -dumpversion)"
    then
        echo "pgcc-config: could not run $program -dumpversion, so there is no version to compare against $version; check that $program is installed and on PATH" >&2
        exit 1
    fi
    if [[ "$rawversion" == "" ]]
    then
        echo "pgcc-config: $program -dumpversion printed no version, so there is nothing to compare against $version" >&2
        exit 1
    fi
    dumpversion="$(echo "$rawversion" | cut -d'.' -f1-2)"

    # Versions are compared as numbers, major first and then minor, in
    # bash's own arithmetic, so any GCC can be compared and not just
    # 4.x.  Sorting them as text gets 4.10 wrong, and "sort -V" isn't on
    # OSX.  The patch level was cut off above, so "gt" and "lt" are
    # about the release a flag arrived in: 4.5.3 is exactly 4.5.  A
    # version given without a minor, like the bare "7" that newer GCCs
    # report, has a minor of 0.
    #
    # Anything that isn't digits gets refused rather than compared,
    # since bash arithmetic would quietly read "4.x" as 4.0 and hand
    # back an answer for a version nobody asked about.
    version_re='^([0-9]+)(\.([0-9]+))?$'
    if [[ ! "$version" =~ $version_re ]]
    then
        echo "pgcc-config: can't compare against version \"$version\": write it as <major>.<minor>, like 4.5" >&2
        exit 1
    fi
    want_major="$((10#${BASH_REMATCH[1]}))"
    want_minor="$((10#${BASH_REMATCH[3]:-0}))"

    if [[ ! "$dumpversion" =~ $version_re ]]
    then
        echo "pgcc-config: $program -dumpversion printed \"$dumpversion\", which isn't a <major>.<minor> version that can be compared" >&2
        exit 1
    fi
    have_major="$((10#${BASH_REMATCH[1]}))"
    have_minor="$((10#${BASH_REMATCH[3]:-0}))"

    # Negative when the compiler is older than the version asked about,
    # positive when it's newer, and zero when it's the same release.
    # Both tests are strict, so a compiler of exactly the given version
    # passes neither: otherwise a Configfile that hands one flag to
    # compilers newer than a version and another to compilers older
    # than it would give both flags to the one on the boundary.
    if (( have_major != want_major ))
    then
        order="$((have_major - want_major))"
    else
        order="$((have_minor - want_minor))"
    fi

    case "$test"
    in
        "gt")
            if (( order > 0 ))
            then
                echo "$flag"
            fi
            exit 0
        ;;

        "lt")
            if (( order < 0 ))
            then
                echo "$flag"
            fi
            exit 0
        ;;
    esac

    echo "Unsupported test $test" >&2
    exit 1
fi

for x in $(seq 9 -1 0)
do
    if [[ "$(which "$program"-"$version"."$x" 2>/dev/null)" != "" ]]
    then
	echo "$program"-"$version"."$x"
	exit 0
    fi
done

echo "\${CC}"
exit 1
