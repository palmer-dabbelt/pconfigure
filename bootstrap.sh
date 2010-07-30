#!/bin/sh

installdir="./bin/"
if [[ "$1" != "" ]]
then
	installdir="$1"
fi

mkdir -p $installdir
ruby src/prbc.rb src/prbc.rb -o $installdir/prbc
ruby src/prbc.rb src/main.rb -o $installdir/pconfigure
ruby src/prbc.rb src/pclean.rb -o $installdir/pclean
