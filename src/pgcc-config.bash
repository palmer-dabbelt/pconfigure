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
    dumpversion="$($program -dumpversion | cut -d'.' -f1-2)"
    match="false"

    if [[ "$(echo "$dumpversion" | cut -d '.' -f 1)" != "4" ]]
    then
        # Comparing arbitrary versions wants "sort -V", which OSX
        # doesn't have, so only GCC 4.x's versions are understood.
        echo "pgcc-config: $program reports version $dumpversion, but only GCC 4.x versions can be compared (OSX doesn't have sort -V)" >&2
        exit 1
    fi

    case "$test"
    in
        "gt")
            first="$(echo -e "$dumpversion\n$version" | sort -k2 -t. -g | head -n1)"
            if [[ "$first" == "$version" ]]
            then
                echo "$flag"
            fi
            exit 0
        ;;

        "lt")
            first="$(echo -e "$dumpversion\n$version" | sort -k2 -t. -g | tail -n1)"
            if [[ "$first" == "$version" ]]
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
