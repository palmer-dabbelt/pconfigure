# Parses some special command-line options
optional="false"
pkgconfig="false"
pkgtarget=""
lastarg=""
have=""
args=""
cmd="pkg-config"
while [[ "$1" != "" ]]
do
    if [[ "$1" == "--optional" ]]
    then
	optional="true"
    elif [[ "$1" == "--pkgconfig" ]]
    then
        pkgconfig="true"
        pkgtarget="$lastarg"
        args="$args --exists"
    elif [[ "$1" == "--have" ]]
    then
	shift
	have="$1"
    elif [[ "$1" == "--ccmd" ]]
    then
        shift
        cmd="$1-config"
    else
	args="$args $1"
        lastarg="$1"
    fi
    
    shift
done

# Actually runs pkg-config.  Its stderr is only thrown away for
# --optional, which asks for a missing package to be no news at all.
# Without it the package is required, and pkg-config's own "Package
# foo was not found in the pkg-config search path", with its hint
# about PKG_CONFIG_PATH, is the only thing that says which package it
# was and where it was looked for: throwing that away too left a
# required package that was missing failing without a word.
if [[ "$optional" == "true" ]]
then
    stdout="$($cmd $args 2> /dev/null)"
else
    stdout="$($cmd $args)"
fi
retval="$?"

# Drops the flags that only name what the toolchain already does by
# default: the directories the linker and loader search anyway, and on
# Darwin a "-lrt" for a library that is part of libSystem there.  These
# have to be compared as whole words.  Removing them as substrings
# (which is what a sed over the output did) also takes the front off
# any longer word that happens to start the same way, so
# "-L/usr/lib/x86_64-linux-gnu/openmpi/lib" came out as the bare path
# "/x86_64-linux-gnu/openmpi/lib" and "-lrtmp" as "mp" -- words the
# compiler driver reads as input files, with the search path or
# library the package asked for gone.  The output is split the way the
# final unquoted echo splits it, with globbing off so a word that
# looks like a pattern is passed along as written.
unwanted=(-L/usr/lib64 -Wl,-rpath,/usr/lib64 -L/usr/lib -Wl,-rpath,/usr/lib)
if [[ "$(uname)" == "Darwin" ]]
then
    unwanted+=(-lrt)
fi
read -r -d '' -a words <<<"$stdout" || true
stdout=""
for word in "${words[@]}"
do
    for drop in "${unwanted[@]}"
    do
        if [[ "$word" == "$drop" ]]
        then
            continue 2
        fi
    done
    stdout="$stdout $word"
done

# If --optional is given then don't panic
if [[ "$retval" != "0" ]]
then
    if [[ "$pkgconfig" == "true" && "$have" != "" ]]
    then
        echo "s/@@HAVE_$have@@//g"
    fi

    if [[ "$optional" == "true" ]]
    then
	exit 0
    else
	exit $retval
    fi
fi

# Checks for some special options
if [[ "$have" != "" ]]
then
    if [[ "$pkgconfig" == "true" ]]
    then
        stdout="$stdout s/@@HAVE_$have@@/$pkgtarget/g"
    else
        stdout="$stdout -DHAVE_$have"
    fi
fi

# Outputs the results of pkg-config
set -f
echo $stdout
exit 0
