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

# Actually runs pkg-config
stdout="$($cmd $args 2> /dev/null)"
retval="$?"
stdout="$(echo "$stdout" | sed 's^-L/usr/lib64^^g' | sed 's^-Wl,-rpath,/usr/lib64^^g' | sed 's^-L/usr/lib^^g' | sed 's^-Wl,-rpath,/usr/lib^^g')"
if [[ "$(uname)" == "Darwin" ]]
then
    stdout="$(echo "$stdout" | sed 's/-lrt//')"
fi

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
echo $stdout
exit 0
