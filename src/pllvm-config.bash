# Parses some special command-line options
optional="false"
have=""
method=""
while [[ "$1" != "" ]]
do
    if [[ "$1" == "--optional" ]]
    then
	optional="true"
    elif [[ "$1" == "--have" ]]
    then
	shift
	have="$1"
    else
	method="$1"
    fi
    
    shift
done

# Check if llvm-config even exists
llvm-config --version >& /dev/null
if [[ "$?" != "0" ]]
then
    if [[ "$optional" == "true" ]]
    then
        exit 0
    else
        exit 1
    fi
fi

# Make llvm-config look a lot like pkg-config
stdout=""
retval=""
if [[ "$method" == "--cflags" ]]
then
    stdout="$(llvm-config --cflags)"
    retval="$?"
elif [[ "$method" == "--libs" ]]
then
    stdout="$(llvm-config --libs core) -lclang -L$(llvm-config --libdir) -Wl,-R$(llvm-config --libdir)"
    retval="$?"
else
    echo "Unsupported method $method" >/dev/stderr
    exit 1
fi

# If --optional is given then don't panic
if [[ "$retval" != "0" ]]
then
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
    stdout="$stdout -DHAVE_$have"
fi

# Outputs the results of pkg-config
echo $stdout | sed 's@-DNDEBUG@@g'
exit 0
